<?php

namespace App\Push;

use App\Models\CalendarEvent;
use App\Models\Rung;
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
        $opens = $window?->opens_at_utc->format('H:i') ?? '';
        $closes = $window?->closes_at_utc->format('H:i') ?? '';
        $reasons = $window
            ? CalendarEvent::query()->whereIn('id', $window->reasons)->orderBy('scheduled_at_utc')->pluck('title')->all()
            : [];
        $events = $reasons === [] ? 'a high-impact release' : implode(', ', array_slice($reasons, 0, 2));

        [$title, $body] = match ($rung->kind) {
            't-60' => ["$instrument window in 60 min", "$events. Restricted $opens to $closes UTC."],
            't-15' => ["$instrument window in 15 min", "$events. Flat by $opens UTC."],
            't-5' => ["$instrument window in 5 min", "$events. Close or hold. Gate at $opens UTC."],
            't-1' => ["One minute: $instrument", "$events. Hands off until $closes UTC."],
            'open' => ["Restricted: $instrument", "$events. Stay out until $closes UTC."],
            'end' => ["Clear: $instrument", "Window closed. Trade at your own pace."],
            default => ["$instrument", $events],
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
