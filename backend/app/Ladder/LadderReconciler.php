<?php

namespace App\Ladder;

use App\Ladder\Jobs\SendRung;
use App\Models\Rung;
use App\Models\User;
use App\Models\Window;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\DB;
use Karnek\RuleEngine\Engine;

/**
 * Recompute a user's windows and ladder for the horizon, then reconcile against
 * what's already scheduled: create missing rungs, cancel rungs whose event moved,
 * leave the rest alone. Rungs already sent are never touched.
 */
final class LadderReconciler
{
    public function __construct(
        private readonly EngineInputBuilder $inputs,
        private readonly int $horizonHours,
    ) {
    }

    /** @return array{created: int, cancelled: int, kept: int, windows: int} */
    public function reconcile(User $user, ?DateTimeImmutable $now = null): array
    {
        $now ??= EngineInputBuilder::utcNow();
        $from = $now->sub(new DateInterval('PT2H'));
        $to = $now->add(new DateInterval('PT' . $this->horizonHours . 'H'));

        $engine = new Engine($this->inputs->packLoader());
        $input = $this->inputs->build($user, $from, $to);
        $result = $engine->computeWindows($input);
        $ladder = $engine->computeLadder($input['userId'], $result['windows']);

        $wanted = [];
        $quiet = QuietHours::fromSettings($user->settings?->quiet_hours, $user->tz ?? 'UTC');
        $stale = $now->sub(new DateInterval('PT30S'));
        foreach ($ladder as $rung) {
            $fireAt = new DateTimeImmutable($rung['fireAtUtc'], new DateTimeZone('UTC'));
            if ($quiet !== null && $quiet->silences($rung['kind'], $fireAt)) {
                continue; // PUSH-ARCHITECTURE: only T-5, T-1 and open fire inside quiet hours
            }
            if ($fireAt < $stale) {
                // Already past: "window in 60 min" sent now would be a lie. The one
                // exception is open while the window is still open, which is news.
                $closes = null;
                foreach ($result['windows'] as $w) {
                    if ($w['windowId'] === $rung['windowId']) {
                        $closes = new DateTimeImmutable($w['closesAtUtc'], new DateTimeZone('UTC'));
                    }
                }
                if (!($rung['kind'] === 'open' && $closes !== null && $now < $closes)) {
                    continue;
                }
            }
            $wanted[$rung['alertId']] = $rung;
        }

        return DB::transaction(function () use ($user, $result, $wanted, $from, $to, $now) {
            // Windows: replace the horizon's set wholesale; they're derived data.
            Window::query()->where('user_id', $user->id)->whereBetween('opens_at_utc', [$from, $to])->delete();
            foreach ($result['windows'] as $w) {
                Window::create([
                    'id' => $w['windowId'],
                    'user_id' => $user->id,
                    'instrument' => $w['instrument'],
                    'opens_at_utc' => $w['opensAtUtc'],
                    'closes_at_utc' => $w['closesAtUtc'],
                    'reasons' => $w['reasons'],
                    'verified' => $w['verified'],
                ]);
            }

            $existing = Rung::query()
                ->where('user_id', $user->id)
                ->where('state', Rung::SCHEDULED)
                ->whereBetween('fire_at_utc', [$from->sub(new DateInterval('PT1H')), $to])
                ->get()
                ->keyBy('alert_id');

            $counts = ['created' => 0, 'cancelled' => 0, 'kept' => 0, 'windows' => count($result['windows'])];

            foreach ($existing as $alertId => $rung) {
                if (isset($wanted[$alertId])) {
                    $counts['kept']++;
                } else {
                    $rung->forceFill(['state' => Rung::CANCELLED])->save();
                    $counts['cancelled']++;
                }
            }

            $alreadyKnown = Rung::query()->whereIn('alert_id', array_keys($wanted))->pluck('state', 'alert_id');
            $toDispatch = [];
            foreach ($wanted as $alertId => $rung) {
                $fireAt = new DateTimeImmutable($rung['fireAtUtc'], new DateTimeZone('UTC'));
                $state = $alreadyKnown->get($alertId);
                if ($state === Rung::CANCELLED) {
                    // The vendor moved the event back, or quiet hours came off: the id
                    // is a pure hash, so the old row comes back to life.
                    Rung::query()->where('alert_id', $alertId)->update(['state' => Rung::SCHEDULED, 'fire_at_utc' => $fireAt]);
                    $toDispatch[$alertId] = $fireAt;
                    $counts['created']++;
                    continue;
                }
                if ($state === Rung::SCHEDULED) {
                    // Kept. If it is overdue its queue job may have been lost (a job
                    // picked up before commit, a Redis flush): dispatch again, the
                    // claim in SendRung makes a second job harmless.
                    if ($fireAt <= $now) {
                        $toDispatch[$alertId] = $fireAt;
                    }
                    continue;
                }
                if ($state !== null) {
                    continue; // sending, sent or failed: never again
                }
                Rung::create([
                    'alert_id' => $alertId,
                    'user_id' => $user->id,
                    'window_id' => $rung['windowId'],
                    'kind' => $rung['kind'],
                    'fire_at_utc' => $fireAt,
                    'state' => Rung::SCHEDULED,
                ]);
                $toDispatch[$alertId] = $fireAt;
                $counts['created']++;
            }

            // Jobs go out once the rows are visible to the worker.
            DB::afterCommit(function () use ($toDispatch) {
                foreach ($toDispatch as $alertId => $fireAt) {
                    SendRung::dispatch($alertId)->onQueue('ladder')->delay($fireAt);
                }
            });

            return $counts;
        });
    }
}
