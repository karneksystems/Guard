<?php

namespace App\Billing;

use DateTimeImmutable;

/**
 * Turns a store receipt into an expiry, or null when the store says no. One
 * implementation per store (App Store Server API, Play Developer API, Microsoft
 * Store collections) lands with the store accounts; the fake accepts its own
 * receipts so the flow can be exercised end to end before then.
 */
interface ReceiptVerifier
{
    /** @return Verified|null the expiry and the store's original transaction id, or null when not valid */
    public function verify(string $platform, string $plan, string $receipt): ?Verified;
}
