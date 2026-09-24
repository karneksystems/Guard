<?php

namespace App\Ladder;

use App\Models\CalendarEvent;
use App\Models\FirmListEvent;
use App\Models\User;
use App\Packs\PackRepository;
use DateTimeImmutable;
use DateTimeZone;

/**
 * Turns a user's rows into the exact input shape fixtures/rule-engine defines,
 * so the server engine sees what the device engine sees.
 */
final class EngineInputBuilder
{
    public function __construct(private readonly PackRepository $packs)
    {
    }

    /**
     * The settings as the plan allows them right now. Pro is enforced at write
     * time too, but an expired subscription must not keep its presets: Free is
     * conservative, five and five, soft gate at most, two instruments.
     */
    public static function clampSettings(User $user): array
    {
        $s = $user->settings;
        $pro = $user->isPro();
        $mode = $s?->mode ?? 'conservative';
        $protection = $s?->protection ?? 'soft-gate';

        return [
            'user_id' => $user->id,
            'mode' => $pro ? $mode : 'conservative',
            'protection' => (!$pro && $protection === 'hard-block') ? 'soft-gate' : $protection,
            'window_before_min' => $pro ? ($s?->window_before_min ?? 5) : 5,
            'window_after_min' => $pro ? ($s?->window_after_min ?? 5) : 5,
            'firm_id' => $pro ? $s?->firm_id : null,
            'account_type_id' => $pro ? $s?->account_type_id : null,
            'quiet_hours' => $s?->quiet_hours,
            'digest_local_time' => $s?->digest_local_time ?? '20:00',
        ];
    }

    public function build(User $user, DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $settings = $user->settings;
        $clamped = self::clampSettings($user);
        $instruments = $user->instruments
            ->map(fn ($i) => ['symbol' => $i->symbol, 'basket' => $i->basket_currencies])
            ->values()
            ->all();
        if (!$user->isPro()) {
            $instruments = array_slice($instruments, 0, 2);
        }
        $input = [
            'userId' => (string) $user->id,
            'settings' => [
                'mode' => $clamped['mode'],
                'windowBeforeMin' => $clamped['window_before_min'],
                'windowAfterMin' => $clamped['window_after_min'],
            ],
            'instruments' => $instruments,
            'events' => CalendarEvent::query()
                ->whereBetween('scheduled_at_utc', [$from, $to])
                ->whereNull('removed_at')
                ->orderBy('scheduled_at_utc')
                ->get()
                ->map(fn (CalendarEvent $e) => $e->toEngineEvent())
                ->values()
                ->all(),
        ];

        if ($clamped['mode'] === 'firm-match' && $settings?->firm_id !== null && $settings->account_type_id !== null) {
            $input['packId'] = $settings->firm_id;
            $input['accountTypeId'] = $settings->account_type_id;
            // The firm's own list, where one has been imported (firm-list:import). The
            // engine only uses it when the pack says eventSet firm-list; with no rows it
            // falls back to the calendar and says so in its notes.
            $ids = FirmListEvent::query()
                ->where('firm_id', $settings->firm_id)
                ->whereNotNull('calendar_event_id')
                ->whereBetween('scheduled_at_utc', [$from, $to])
                ->pluck('calendar_event_id')
                ->map(fn ($id) => (string) $id)
                ->values()
                ->all();
            if ($ids !== []) {
                $input['firmEventIds'] = $ids;
            }
        }

        return $input;
    }

    public function packLoader(): callable
    {
        return fn (string $firmId): array => $this->packs->load($firmId);
    }

    public static function utcNow(): DateTimeImmutable
    {
        return new DateTimeImmutable('now', new DateTimeZone('UTC'));
    }
}
