<?php

namespace App\Billing;

use DateInterval;
use DateTimeImmutable;
use DateTimeZone;

/** Accepts "fake:monthly" and "fake:yearly" on the fake platform, nothing else. */
final class FakeVerifier implements ReceiptVerifier
{
    public function verify(string $platform, string $plan, string $receipt): ?DateTimeImmutable
    {
        if ($platform !== 'fake' || $receipt !== 'fake:' . $plan) {
            return null;
        }
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        return $now->add(new DateInterval($plan === 'yearly' ? 'P1Y' : 'P1M'));
    }
}
