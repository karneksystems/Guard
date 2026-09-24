<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Device;
use App\Models\Profile;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

final class DeviceController extends Controller
{
    /** Anonymous registration: creates a user, a device, default settings, and the hub profile skeleton. */
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'platform' => ['required', 'in:android,ios,windows,macos'],
            'tz' => ['nullable', 'string', 'max:64', 'timezone:all'],
            'app_version' => ['nullable', 'string', 'max:32'],
        ]);

        [$plain, $hash] = Device::issueToken();

        $device = DB::transaction(function () use ($data, $hash) {
            $user = User::create(['tz' => $data['tz'] ?? 'UTC']);
            Setting::create(['user_id' => $user->id]);
            Profile::create(['user_id' => $user->id]);

            return Device::create([
                'user_id' => $user->id,
                'platform' => $data['platform'],
                'api_token_hash' => $hash,
                'tz' => $data['tz'] ?? 'UTC',
                'app_version' => $data['app_version'] ?? null,
            ]);
        });

        return response()->json(['deviceId' => $device->id, 'token' => $plain], 201);
    }

    /** Push token and permission state, reported by the app whenever they change. */
    public function update(Request $request): JsonResponse
    {
        $data = $request->validate([
            'push_token' => ['nullable', 'string'],
            'notif_state' => ['nullable', 'in:unknown,granted,denied,invalid'],
            'tz' => ['nullable', 'string', 'max:64', 'timezone:all'],
            'app_version' => ['nullable', 'string', 'max:32'],
        ]);
        /** @var Device $device */
        $device = $request->attributes->get('device');
        if (array_key_exists('push_token', $data)) {
            $data['token_valid'] = $data['push_token'] !== null;
        }
        $device->fill($data)->save();
        // Quiet hours follow the user, and the user follows their latest device.
        if (!empty($data['tz']) && $device->user->tz !== $data['tz']) {
            $device->user->forceFill(['tz' => $data['tz']])->save();
        }

        return response()->json(['ok' => true]);
    }
}
