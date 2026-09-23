<?php

namespace App\Calendar;

use DateTimeImmutable;
use DateTimeZone;

/**
 * Serves events from a JSON file, or from an array set at runtime in tests.
 * File shape: [{"vendorId":"...","currency":"USD","title":"...","impact":"high",
 *               "scheduledAtUtc":"2026-10-02T12:30:00Z","tentative":false}]
 */
final class FakeVendor implements VendorAdapter
{
    /** @var list<array>|null */
    private ?array $events = null;

    public function __construct(private readonly ?string $path = null)
    {
    }

    public function name(): string
    {
        return 'fake';
    }

    /** @param list<array> $events */
    public function setEvents(array $events): void
    {
        $this->events = $events;
    }

    public function fetch(DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $rows = $this->events;
        if ($rows === null) {
            $rows = ($this->path !== null && is_file($this->path))
                ? json_decode((string) file_get_contents($this->path), true, 512, JSON_THROW_ON_ERROR)
                : [];
        }

        $out = [];
        foreach ($rows as $row) {
            $at = $row['scheduledAtUtc'] instanceof DateTimeImmutable
                ? $row['scheduledAtUtc']
                : new DateTimeImmutable($row['scheduledAtUtc'], new DateTimeZone('UTC'));
            if ($at < $from || $at > $to) {
                continue;
            }
            $out[] = [
                'vendorId' => (string) $row['vendorId'],
                'currency' => $row['currency'],
                'title' => $row['title'],
                'impact' => $row['impact'],
                'scheduledAtUtc' => $at->setTimezone(new DateTimeZone('UTC')),
                'tentative' => (bool) ($row['tentative'] ?? false),
                'source' => $row['source'] ?? 'fake calendar',
            ];
        }

        return $out;
    }
}
