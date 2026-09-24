<?php

namespace App\Push;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * APNs over HTTP/2 with token-based auth (a .p8 key). One JWT per 50 minutes,
 * cached. interruption-level from the message, apns-collapse-id = alert id.
 */
final class ApnsSender
{
    public function __construct(
        private readonly string $teamId,
        private readonly string $keyId,
        private readonly string $privateKeyPem,
        private readonly string $bundleId,
        private readonly bool $sandbox = false,
    ) {
    }

    public function host(): string
    {
        return $this->sandbox ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com';
    }

    /** @return string apns-id from the response, or an empty string */
    public function send(string $deviceToken, RungMessage $m, int $expiresAtUnix): string
    {
        $payload = [
            'aps' => [
                'alert' => ['title' => $m->title, 'body' => $m->body],
                'sound' => 'default',
                'interruption-level' => $m->level,
                'relevance-score' => $m->kind === 'open' ? 1.0 : 0.8,
                'thread-id' => $m->windowId,
            ],
        ] + $m->data();

        $response = Http::withOptions(['version' => 2.0, 'timeout' => 10])
            ->withHeaders([
                'authorization' => 'bearer ' . $this->token(),
                'apns-topic' => $this->bundleId,
                'apns-push-type' => 'alert',
                'apns-priority' => '10',
                'apns-collapse-id' => $m->alertId,
                'apns-expiration' => (string) $expiresAtUnix,
            ])
            ->post($this->host() . '/3/device/' . $deviceToken, $payload);

        if ($response->successful()) {
            return (string) $response->header('apns-id');
        }

        $reason = (string) ($response->json('reason') ?? 'Unknown');
        $dead = $response->status() === 410 || in_array($reason, ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic'], true);
        throw new PushRejected("APNs {$response->status()} $reason", prune: $dead, status: $response->status());
    }

    /** Background push: content-available, priority 5, no alert. Wakes the app to resync. */
    public function sendSilent(string $deviceToken, array $data): void
    {
        $response = Http::withOptions(['version' => 2.0, 'timeout' => 10])
            ->withHeaders([
                'authorization' => 'bearer ' . $this->token(),
                'apns-topic' => $this->bundleId,
                'apns-push-type' => 'background',
                'apns-priority' => '5',
                'apns-expiration' => (string) (time() + 3600),
            ])
            ->post($this->host() . '/3/device/' . $deviceToken, ['aps' => ['content-available' => 1]] + $data);

        if (!$response->successful()) {
            $reason = (string) ($response->json('reason') ?? 'Unknown');
            $dead = $response->status() === 410 || in_array($reason, ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic'], true);
            throw new PushRejected("APNs {$response->status()} $reason", prune: $dead, status: $response->status());
        }
    }

    public function token(): string
    {
        return Cache::remember('apns.jwt.' . $this->keyId, now()->addMinutes(50), function () {
            return Jwt::es256(['kid' => $this->keyId], ['iss' => $this->teamId, 'iat' => time()], $this->privateKeyPem);
        });
    }
}
