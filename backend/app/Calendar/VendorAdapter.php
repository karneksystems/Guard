<?php

namespace App\Calendar;

use DateTimeImmutable;

/**
 * One implementation per licensed vendor. No scraping, per the brief.
 *
 * Each returned event is a normalised array:
 *   vendorId, currency, title, impact (high|medium|low), scheduledAtUtc (DateTimeImmutable, UTC),
 *   tentative (bool), source (string shown on the app's source strip).
 */
interface VendorAdapter
{
    public function name(): string;

    /** @return list<array{vendorId: string, currency: string, title: string, impact: string, scheduledAtUtc: DateTimeImmutable, tentative: bool, source: string}> */
    public function fetch(DateTimeImmutable $from, DateTimeImmutable $to): array;
}
