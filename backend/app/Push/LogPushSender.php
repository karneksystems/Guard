<?php

namespace App\Push;

use App\Models\Device;
use App\Models\Rung;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/** Development sender: writes the rung to the log and returns a fake message id. */
final class LogPushSender implements PushSender
{
    public function sendRung(Rung $rung): ?string
    {
        $devices = Device::query()
            ->where('user_id', $rung->user_id)
            ->where('token_valid', true)
            ->count();

        Log::info('rung', [
            'alertId' => $rung->alert_id,
            'kind' => $rung->kind,
            'fireAtUtc' => $rung->fire_at_utc->format('Y-m-d\TH:i:s\Z'),
            'devices' => $devices,
        ]);

        return 'log-' . Str::lower(Str::random(12));
    }
}
