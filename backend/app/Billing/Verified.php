<?php

namespace App\Billing;

use DateTimeImmutable;

/** What a store verifier hands back: when it expires and which purchase it is. */
final class Verified
{
    public function __construct(
        public readonly DateTimeImmutable $expiresAt,
        public readonly string $originalTransactionId,
    ) {
    }
}
