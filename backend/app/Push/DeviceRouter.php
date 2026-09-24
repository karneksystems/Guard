<?php

namespace App\Push;

use App\Models\Device;
use App\Models\Rung;
use Illuminate\Support\Facades\Log;

/**
 * The live PushSender: one rung, every valid device of the user, the right
 * provider per platform. A dead token is pruned; a transient failure is thrown
 * so the job retries and the mirror covers the gap. Windows and macOS sockets
 * arrive with M5; until then those devices rely on the local mirror.
 */
final class DeviceRouter implements PushSender
{
    public function __construct(
        private readonly ?ApnsSender $apns,
        private readonly ?FcmSender $fcm,
        private readonly int $expiryGraceSeconds = 600,
    ) {
    }

    public function sendRung(Rung $rung): ?string
    {
        $message = RungMessage::for($rung);
        $expiresAt = $rung->fire_at_utc->getTimestamp() + $this->expiryGraceSeconds;
        $devices = Device::query()
            ->where('user_id', $rung->user_id)
            ->where('token_valid', true)
            ->whereNotNull('push_token')
            ->get();

        $firstId = null;
        $transient = null;
        foreach ($devices as $device) {
            try {
                $id = match ($device->platform) {
                    'ios', 'macos' => $this->apns?->send($device->push_token, $message, $expiresAt),
                    'android' => $this->fcm?->send($device->push_token, $message, max(0, $expiresAt - time())),
                    default => null, // windows: socket in M5
                };
                $firstId ??= $id;
            } catch (PushRejected $e) {
                if ($e->prune) {
                    $device->forceFill(['token_valid' => false, 'notif_state' => 'invalid'])->save();
                    Log::info('push token pruned', ['device' => $device->id, 'reason' => $e->getMessage()]);
                } else {
                    $transient = $e;
                    Log::warning('push transient failure', ['device' => $device->id, 'reason' => $e->getMessage()]);
                }
            }
        }

        if ($firstId === null && $transient !== null) {
            throw $transient; // nothing got through; let the job retry
        }

        return $firstId;
    }
}
