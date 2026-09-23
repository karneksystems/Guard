<?php

namespace App\Events;

use App\Models\CalendarEvent;
use DateTimeImmutable;
use Illuminate\Foundation\Events\Dispatchable;

final class CalendarEventChanged
{
    use Dispatchable;

    public function __construct(
        public readonly CalendarEvent $event,
        public readonly DateTimeImmutable $previouslyScheduledAtUtc,
    ) {
    }
}
