<?php

namespace App\Ladder;

use App\Models\CalendarEvent;
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

    public function build(User $user, DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $settings = $user->settings;
        $input = [
            'userId' => (string) $user->id,
            'settings' => [
                'mode' => $settings?->mode ?? 'conservative',
                'windowBeforeMin' => $settings?->window_before_min ?? 5,
                'windowAfterMin' => $settings?->window_after_min ?? 5,
            ],
            'instruments' => $user->instruments
                ->map(fn ($i) => ['symbol' => $i->symbol, 'basket' => $i->basket_currencies])
                ->values()
                ->all(),
            'events' => CalendarEvent::query()
                ->whereBetween('scheduled_at_utc', [$from, $to])
                ->orderBy('scheduled_at_utc')
                ->get()
                ->map(fn (CalendarEvent $e) => $e->toEngineEvent())
                ->values()
                ->all(),
        ];

        if (($settings?->mode ?? 'conservative') === 'firm-match' && $settings->firm_id !== null) {
            $input['packId'] = $settings->firm_id;
            $input['accountTypeId'] = $settings->account_type_id;
            // firmEventIds is populated once a firm's own list is ingested. Until then the
            // engine falls back to the calendar and says so in its notes.
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
