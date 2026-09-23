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

    /** @return array{created: int, changed: int, unchanged: int} */
    public function sync(DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $counts = ['created' => 0, 'changed' => 0, 'unchanged' => 0];

        foreach ($this->vendor->fetch($from, $to) as $row) {
            $existing = CalendarEvent::query()
                ->where('vendor', $this->vendor->name())
                ->where('vendor_id', $row['vendorId'])
                ->first();

            if ($existing === null) {
                CalendarEvent::create([
                    'vendor' => $this->vendor->name(),
                    'vendor_id' => $row['vendorId'],
                    'currency' => $row['currency'],
                    'title' => $row['title'],
                    'impact' => $row['impact'],
                    'scheduled_at_utc' => $row['scheduledAtUtc'],
                    'tentative' => $row['tentative'],
                    'source' => $row['source'],
                    'fetched_at' => $now,
                ]);
                $counts['created']++;
                continue;
            }

            $moved = $existing->scheduled_at_utc->getTimestamp() !== $row['scheduledAtUtc']->getTimestamp();
            $changed = $moved
                || $existing->impact !== $row['impact']
                || $existing->currency !== $row['currency']
                || $existing->tentative !== $row['tentative'];

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
            ])->save();
            $counts['changed']++;

            CalendarEventChanged::dispatch($existing, $previous);
        }

        return $counts;
    }
}
