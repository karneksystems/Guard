<?php

namespace App\Billing;

use DateInterval;
use DateTimeImmutable;
use DateTimeZone;

/** Accepts "fake:monthly" and "fake:yearly" on the fake platform, nothing else. */
final class FakeVerifier implements ReceiptVerifier
{
    public function verify(string $platform, string $plan, string $receipt): ?Verified
    {
        if ($platform !== 'fake' || !str_starts_with($receipt, 'fake:' . $plan)) {
            return null;
        }
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        // "fake:monthly" or "fake:monthly:tx-123" for a specific transaction id.
        return new Verified($now->add(new DateInterval($plan === 'yearly' ? 'P1Y' : 'P1M')), $receipt);
    }
}
