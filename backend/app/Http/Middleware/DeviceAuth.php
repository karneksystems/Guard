<?php

namespace App\Http\Middleware;

use App\Models\Device;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Bearer token issued at device registration. Attaches the device and its user. */
final class DeviceAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $device = Device::findByToken($request->bearerToken());
        if ($device === null) {
            return response()->json(['error' => 'unauthenticated'], 401);
        }
        $device->forceFill(['last_seen_at' => now()])->saveQuietly();
        $request->attributes->set('device', $device);
        $request->setUserResolver(fn () => $device->user);

        return $next($request);
    }
}
