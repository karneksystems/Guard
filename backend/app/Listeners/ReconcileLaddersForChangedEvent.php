<?php

namespace App\Listeners;

use App\Events\CalendarEventChanged;
use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\Instrument;

/**
 * A moved event only matters to users whose baskets contain its currency.
 * Queue one reconcile per affected user; the job is idempotent.
 */
final class ReconcileLaddersForChangedEvent
{
    public function handle(CalendarEventChanged $changed): void
    {
        $currency = $changed->event->currency;
        $userIds = Instrument::query()
            ->whereJsonContains('basket_currencies', $currency)
            ->distinct()
            ->pluck('user_id');

        foreach ($userIds as $userId) {
            ReconcileUserLadder::dispatch((int) $userId);
        }
    }
}
