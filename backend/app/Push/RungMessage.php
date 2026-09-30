<?php

namespace App\Push;

use App\Models\CalendarEvent;
use App\Models\Rung;
use App\Models\User;
use App\Models\Window;

/**
 * What a rung says, and how loud. Same words on every platform; the platform
 * senders decide how to carry them (docs/PUSH-ARCHITECTURE.md).
 */
final class RungMessage
{
    private function __construct(
        public readonly string $title,
        public readonly string $body,
        public readonly string $level,     // time-sensitive | active
        public readonly string $channel,   // ladder_urgent | ladder
        public readonly string $alertId,
        public readonly string $windowId,
        public readonly string $kind,
        public readonly string $instrument,
        public readonly string $opensAtUtc,
        public readonly string $closesAtUtc,
    ) {
    }

    public static function for(Rung $rung): self
    {
        $window = Window::query()->find($rung->window_id);
        $instrument = $window?->instrument ?? 'your instrument';
        // Local times, in the user's own zone (docs/redesign/grok-final/COPY.md).
        $tz = new \DateTimeZone(User::query()->find($rung->user_id)?->tz ?: 'UTC');
        $opens = $window?->opens_at_utc->setTimezone($tz)->format('G:i') ?? '';
        $closes = $window?->closes_at_utc->setTimezone($tz)->format('G:i') ?? '';
        $events = $window
            ? CalendarEvent::query()->whereIn('id', $window->reasons)->orderBy('scheduled_at_utc')->get()
                ->map(fn (CalendarEvent $e) => EventNames::short($e->currency, $e->title))->unique()->values()->all()
            : [];
        $events = $events === [] ? 'High impact news' : implode(', ', array_slice($events, 0, 2));
        $market = EventNames::market($instrument);
        $spoken = in_array($market, ['Gold', 'Silver', 'Oil'], true) ? strtolower($market) : $market;

        [$title, $body] = match ($rung->kind) {
            't-60' => ["$market cover in 60 min", "$events. Stay flat from $opens to $closes."],
            't-15' => ["$market cover in 15 min", "$events. Be flat by $opens."],
            't-5' => ["$market cover in 5 min", "$events. Close or hold. Cover starts at $opens."],
            't-1' => ["One minute · $spoken", "$events. Hands off until $closes."],
            'open' => ["Cover is on · $spoken", "$events. Stay out until $closes."],
            'end' => ["You're clear · $spoken", 'Cover ended. Trade at your own pace.'],
            default => [$market, $events],
        };

        return new self(
            title: $title,
            body: $body,
            level: $rung->kind === 't-60' ? 'active' : 'time-sensitive',
            channel: in_array($rung->kind, ['t-1', 'open'], true) ? 'ladder_urgent' : 'ladder',
            alertId: $rung->alert_id,
            windowId: $rung->window_id,
            kind: $rung->kind,
            instrument: $instrument,
            opensAtUtc: $window?->opens_at_utc->format('Y-m-d\TH:i:s\Z') ?? '',
            closesAtUtc: $window?->closes_at_utc->format('Y-m-d\TH:i:s\Z') ?? '',
        );
    }

    /** Data the app uses to dedupe against the local mirror and to render itself. */
    public function data(): array
    {
        return [
            'alertId' => $this->alertId,
            'windowId' => $this->windowId,
            'kind' => $this->kind,
            'channel' => $this->channel,
            'instrument' => $this->instrument,
            'opensAtUtc' => $this->opensAtUtc,
            'closesAtUtc' => $this->closesAtUtc,
            'title' => $this->title,
            'body' => $this->body,
        ];
    }
}
