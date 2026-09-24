<?php

namespace App\Push;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * FCM HTTP v1 with a service account. Data-only, high priority, so the app
 * builds the notification itself and owns channels and the full-screen intent.
 */
final class FcmSender
{
    private readonly string $projectId;
    private readonly string $clientEmail;
    private readonly string $privateKeyPem;

    public function __construct(array $serviceAccount, private readonly string $tokenUrl = 'https://oauth2.googleapis.com/token')
    {
        foreach (['project_id', 'client_email', 'private_key'] as $k) {
            if (empty($serviceAccount[$k])) {
                throw new RuntimeException("FCM service account is missing $k");
            }
        }
        $this->projectId = $serviceAccount['project_id'];
        $this->clientEmail = $serviceAccount['client_email'];
        $this->privateKeyPem = $serviceAccount['private_key'];
    }

    public function endpoint(): string
    {
        return 'https://fcm.googleapis.com/v1/projects/' . $this->projectId . '/messages:send';
    }

    /** @return string FCM message name */
    public function send(string $deviceToken, RungMessage $m, int $ttlSeconds): string
    {
        $data = array_map(static fn ($v) => (string) $v, $m->data());
        $response = Http::withToken($this->accessToken())
            ->timeout(10)
            ->post($this->endpoint(), [
                'message' => [
                    'token' => $deviceToken,
                    'data' => $data,
                    'android' => [
                        'priority' => 'high',
                        'ttl' => max(0, $ttlSeconds) . 's',
                        'collapse_key' => $m->alertId,
                    ],
                ],
            ]);

        if ($response->successful()) {
            return (string) ($response->json('name') ?? '');
        }

        $status = (string) ($response->json('error.status') ?? '');
        $details = $response->json('error.details') ?? [];
        $code = '';
        foreach ($details as $d) {
            if (isset($d['errorCode'])) {
                $code = $d['errorCode'];
            }
        }
        $dead = $response->status() === 404 || $code === 'UNREGISTERED' || $status === 'NOT_FOUND';
        throw new PushRejected("FCM {$response->status()} $status $code", prune: $dead, status: $response->status());
    }

    /** Data-only message at high priority; the app resyncs on receipt and shows nothing. */
    public function sendSilent(string $deviceToken, array $data): void
    {
        $response = Http::withToken($this->accessToken())
            ->timeout(10)
            ->post($this->endpoint(), [
                'message' => [
                    'token' => $deviceToken,
                    'data' => array_map(static fn ($v) => (string) $v, $data),
                    'android' => ['priority' => 'high', 'ttl' => '3600s', 'collapse_key' => 'resync'],
                ],
            ]);

        if (!$response->successful()) {
            $status = (string) ($response->json('error.status') ?? '');
            $dead = $response->status() === 404 || $status === 'NOT_FOUND';
            throw new PushRejected("FCM {$response->status()} $status", prune: $dead, status: $response->status());
        }
    }

    public function accessToken(): string
    {
        return Cache::remember('fcm.access.' . md5($this->clientEmail), now()->addMinutes(50), function () {
            $now = time();
            $assertion = Jwt::rs256([], [
                'iss' => $this->clientEmail,
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => $this->tokenUrl,
                'iat' => $now,
                'exp' => $now + 3600,
            ], $this->privateKeyPem);

            $response = Http::asForm()->timeout(10)->post($this->tokenUrl, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ])->throw();

            return (string) $response->json('access_token');
        });
    }
}
