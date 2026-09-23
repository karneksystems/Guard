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
        foreach ($ladder as $rung) {
            $wanted[$rung['alertId']] = $rung;
        }

        return DB::transaction(function () use ($user, $result, $wanted, $from, $to) {
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
            foreach ($wanted as $alertId => $rung) {
                if ($alreadyKnown->has($alertId)) {
                    continue; // scheduled (kept above), or sent, or cancelled by hand: never re-create
                }
                $fireAt = new DateTimeImmutable($rung['fireAtUtc'], new DateTimeZone('UTC'));
                Rung::create([
                    'alert_id' => $alertId,
                    'user_id' => $user->id,
                    'window_id' => $rung['windowId'],
                    'kind' => $rung['kind'],
                    'fire_at_utc' => $fireAt,
                    'state' => Rung::SCHEDULED,
                ]);
                SendRung::dispatch($alertId)->onQueue('ladder')->delay($fireAt);
                $counts['created']++;
            }

            return $counts;
        });
    }
}
