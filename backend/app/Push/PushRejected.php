<?php

namespace App\Push;

use RuntimeException;

/** A provider refused a token. $prune says whether the token is dead for good. */
final class PushRejected extends RuntimeException
{
    public function __construct(string $message, public readonly bool $prune, public readonly int $status = 0)
    {
        parent::__construct($message);
    }
}
