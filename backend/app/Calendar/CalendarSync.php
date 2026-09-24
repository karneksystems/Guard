<?php

namespace App\Calendar;

use App\Events\CalendarEventChanged;
use App\Models\CalendarEvent;
use DateTimeImmutable;
use DateTimeZone;

/**
 * Mirrors the vendor feed into calendar_events and reports what moved.
 * Runs every 15 minutes across the horizon, and every minute inside the two hours
 * around a high-impact event (see routes/console.php).
 */
final class CalendarSync
{
    public function __construct(private readonly VendorAdapter $vendor)
    {
    }

    /** @return array{created: int, changed: int, unchanged: int, removed: int} */
    public function sync(DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $counts = ['created' => 0, 'changed' => 0, 'unchanged' => 0, 'removed' => 0];
        $rows = $this->vendor->fetch($from, $to);
        $seen = [];

        foreach ($rows as $row) {
            $seen[] = $row['vendorId'];
            $existing = CalendarEvent::query()
                ->where('vendor', $this->vendor->name())
                ->where('vendor_id', $row['vendorId'])
                ->first();

            if ($existing === null) {
                // Two syncs can race on a new row (the full sweep and the tight one);
                // the unique index makes the loser's create a no-op update.
                CalendarEvent::query()->upsert([[
                    'vendor' => $this->vendor->name(),
                    'vendor_id' => $row['vendorId'],
                    'currency' => $row['currency'],
                    'title' => $row['title'],
                    'impact' => $row['impact'],
                    'scheduled_at_utc' => $row['scheduledAtUtc'],
                    'tentative' => $row['tentative'],
                    'source' => $row['source'],
                    'fetched_at' => $now,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]], ['vendor', 'vendor_id'], ['fetched_at', 'updated_at']);
                $counts['created']++;
                continue;
            }

            $moved = $existing->scheduled_at_utc->getTimestamp() !== $row['scheduledAtUtc']->getTimestamp();
            $changed = $moved
                || $existing->impact !== $row['impact']
                || $existing->currency !== $row['currency']
                || $existing->tentative !== $row['tentative']
                || $existing->removed_at !== null;

            if (!$changed) {
                $existing->forceFill(['fetched_at' => $now])->saveQuietly();
                $counts['unchanged']++;
                continue;
            }

            $previous = $existing->scheduled_at_utc;
            $existing->fill([
                'currency' => $row['currency'],
                'title' => $row['title'],
                'impact' => $row['impact'],
                'scheduled_at_utc' => $row['scheduledAtUtc'],
                'revised_from_utc' => $moved ? $previous : $existing->revised_from_utc,
                'tentative' => $row['tentative'],
                'fetched_at' => $now,
                'removed_at' => null,
            ])->save();
            $counts['changed']++;

            CalendarEventChanged::dispatch($existing, $previous);
        }

        // Events the feed no longer lists inside the fetched range are cancelled
        // releases: keep the row for the journal, stop it opening windows, and
        // tell the ladder. Only when the vendor answered at all, so an empty or
        // broken response never wipes the calendar.
        if ($rows !== []) {
            $vanished = CalendarEvent::query()
                ->where('vendor', $this->vendor->name())
                ->whereNull('removed_at')
                ->whereBetween('scheduled_at_utc', [$from, $to])
                ->whereNotIn('vendor_id', $seen)
                ->get();
            foreach ($vanished as $event) {
                $event->forceFill(['removed_at' => $now])->save();
                $counts['removed']++;
                CalendarEventChanged::dispatch($event, $event->scheduled_at_utc);
            }
        }

        return $counts;
    }
}
