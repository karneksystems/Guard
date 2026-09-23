<?php

namespace App\Push;

use App\Models\Rung;

/**
 * Delivers one rung to every valid device of the rung's user.
 * APNs and FCM implementations land in M3 (docs/PUSH-ARCHITECTURE.md).
 */
interface PushSender
{
    /** @return string|null provider message id, if the provider gives one */
    public function sendRung(Rung $rung): ?string;
}
