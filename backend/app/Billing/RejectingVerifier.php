<?php

namespace App\Billing;

use DateTimeImmutable;

/** Bound in production until the store verifiers exist: nothing gets Pro by accident. */
final class RejectingVerifier implements ReceiptVerifier
{
    public function verify(string $platform, string $plan, string $receipt): ?DateTimeImmutable
    {
        return null;
    }
}
