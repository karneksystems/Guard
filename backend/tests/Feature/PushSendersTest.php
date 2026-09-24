<?php

namespace Tests\Feature;

use App\Models\CalendarEvent;
use App\Models\Device;
use App\Models\Rung;
use App\Models\User;
use App\Models\Window;
use App\Push\ApnsSender;
use App\Push\DeviceRouter;
use App\Push\FcmSender;
use App\Push\Jwt;
use App\Push\PushRejected;
use App\Push\RungMessage;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

final class PushSendersTest extends TestCase
{
    use RefreshDatabase;

    private static function ecKey(): array
    {
        $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        openssl_pkey_export($key, $pem);

        return [$pem, openssl_pkey_get_details($key)['key']];
    }

    private static function rsaKey(): array
    {
        $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_RSA, 'private_key_bits' => 2048]);
        openssl_pkey_export($key, $pem);

        return [$pem, openssl_pkey_get_details($key)['key']];
    }

    private function rung(string $kind = 'open'): Rung
    {
        $user = User::create(['tz' => 'UTC']);
        $event = CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'nfp', 'currency' => 'USD', 'title' => 'Non-Farm Payrolls', 'impact' => 'high',
            'scheduled_at_utc' => new DateTimeImmutable('2026-10-02T12:30:00Z', new DateTimeZone('UTC')), 'source' => 'fake',
        ]);
        Window::create([
            'id' => str_repeat('w', 20), 'user_id' => $user->id, 'instrument' => 'XAUUSD',
            'opens_at_utc' => new DateTimeImmutable('2026-10-02T12:25:00Z', new DateTimeZone('UTC')),
            'closes_at_utc' => new DateTimeImmutable('2026-10-02T12:35:00Z', new DateTimeZone('UTC')),
            'reasons' => [(string) $event->id], 'verified' => true,
        ]);

        return Rung::create([
            'alert_id' => str_repeat('a', 20), 'user_id' => $user->id, 'window_id' => str_repeat('w', 20),
            'kind' => $kind, 'fire_at_utc' => new DateTimeImmutable('2026-10-02T12:25:00Z', new DateTimeZone('UTC')),
        ]);
    }

    public function test_es256_jwt_verifies_with_openssl(): void
    {
        [$pem, $pub] = self::ecKey();
        $jwt = Jwt::es256(['kid' => 'K1'], ['iss' => 'TEAM', 'iat' => 1], $pem);
        [$h, $c, $s] = explode('.', $jwt);
        $this->assertSame(['kid' => 'K1', 'alg' => 'ES256', 'typ' => 'JWT'], json_decode(Jwt::unb64($h), true));
        $this->assertSame(64, strlen(Jwt::unb64($s)));
        $der = Jwt::rawToDer(Jwt::unb64($s), 32);
        $this->assertSame(1, openssl_verify("$h.$c", $der, $pub, OPENSSL_ALGO_SHA256));
    }

    public function test_rs256_jwt_verifies_with_openssl(): void
    {
        [$pem, $pub] = self::rsaKey();
        $jwt = Jwt::rs256([], ['iss' => 'svc@example.iam', 'iat' => 1], $pem);
        [$h, $c, $s] = explode('.', $jwt);
        $this->assertSame(1, openssl_verify("$h.$c", Jwt::unb64($s), $pub, OPENSSL_ALGO_SHA256));
    }

    public function test_rung_message_words_and_levels(): void
    {
        $open = RungMessage::for($this->rung('open'));
        $this->assertSame('Restricted: XAUUSD', $open->title);
        $this->assertSame('Non-Farm Payrolls. Stay out until 12:35 UTC.', $open->body);
        $this->assertSame('time-sensitive', $open->level);
        $this->assertSame('ladder_urgent', $open->channel);

        $t60 = RungMessage::for(Rung::create([
            'alert_id' => str_repeat('b', 20), 'user_id' => $open->alertId ? Rung::first()->user_id : 1, 'window_id' => str_repeat('w', 20),
            'kind' => 't-60', 'fire_at_utc' => new DateTimeImmutable('2026-10-02T11:25:00Z', new DateTimeZone('UTC')),
        ]));
        $this->assertSame('active', $t60->level);
        $this->assertSame('ladder', $t60->channel);
    }

    public function test_apns_sends_time_sensitive_alert_with_collapse_id(): void
    {
        [$pem] = self::ecKey();
        Http::fake(['api.sandbox.push.apple.com/*' => Http::response('', 200, ['apns-id' => 'abc-123'])]);
        $sender = new ApnsSender('TEAM', 'K1', $pem, 'com.stanchion.guard', sandbox: true);

        $id = $sender->send('devtoken', RungMessage::for($this->rung('open')), 1_800_000_000);

        $this->assertSame('abc-123', $id);
        Http::assertSent(function (Request $r) {
            $body = $r->data();

            return str_ends_with($r->url(), '/3/device/devtoken')
                && $r->hasHeader('apns-topic', 'com.stanchion.guard')
                && $r->hasHeader('apns-collapse-id', str_repeat('a', 20))
                && $r->hasHeader('apns-push-type', 'alert')
                && str_starts_with($r->header('authorization')[0], 'bearer ')
                && $body['aps']['interruption-level'] === 'time-sensitive'
                && $body['aps']['alert']['title'] === 'Restricted: XAUUSD'
                && $body['kind'] === 'open';
        });
    }

    public function test_apns_410_marks_the_token_dead(): void
    {
        [$pem] = self::ecKey();
        Http::fake(['api.push.apple.com/*' => Http::response(['reason' => 'Unregistered'], 410)]);
        $sender = new ApnsSender('TEAM', 'K1', $pem, 'com.stanchion.guard');

        try {
            $sender->send('devtoken', RungMessage::for($this->rung()), 1_800_000_000);
            $this->fail('expected rejection');
        } catch (PushRejected $e) {
            $this->assertTrue($e->prune);
            $this->assertSame(410, $e->status);
        }
    }

    public function test_fcm_exchanges_a_service_account_jwt_then_sends_data_only(): void
    {
        [$pem] = self::rsaKey();
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3599]),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/guard-test/messages/0:1']),
        ]);
        $sender = new FcmSender(['project_id' => 'guard-test', 'client_email' => 'svc@guard-test.iam.gserviceaccount.com', 'private_key' => $pem]);

        $name = $sender->send('fcmtoken', RungMessage::for($this->rung('t-1')), 600);

        $this->assertSame('projects/guard-test/messages/0:1', $name);
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'oauth2.googleapis.com')
            && $r['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            && substr_count($r['assertion'], '.') === 2);
        Http::assertSent(function (Request $r) {
            if (!str_contains($r->url(), 'fcm.googleapis.com/v1/projects/guard-test/messages:send')) {
                return false;
            }
            $m = $r->data()['message'];

            return $m['token'] === 'fcmtoken'
                && $m['android']['priority'] === 'high'
                && $m['android']['ttl'] === '600s'
                && $m['data']['channel'] === 'ladder_urgent'
                && $m['data']['kind'] === 't-1'
                && !isset($m['notification'])
                && $r->hasHeader('Authorization', 'Bearer ya29.test');
        });
    }

    public function test_fcm_unregistered_marks_the_token_dead(): void
    {
        [$pem] = self::rsaKey();
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.test']),
            'fcm.googleapis.com/*' => Http::response(['error' => ['status' => 'NOT_FOUND', 'details' => [['errorCode' => 'UNREGISTERED']]]], 404),
        ]);
        $sender = new FcmSender(['project_id' => 'p', 'client_email' => 'e@x', 'private_key' => $pem]);

        $this->expectException(PushRejected::class);
        try {
            $sender->send('dead', RungMessage::for($this->rung()), 60);
        } catch (PushRejected $e) {
            $this->assertTrue($e->prune);
            throw $e;
        }
    }

    public function test_router_sends_per_platform_and_prunes_dead_tokens(): void
    {
        [$ec] = self::ecKey();
        [$rsa] = self::rsaKey();
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.test']),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/p/messages/1']),
            'api.push.apple.com/*' => Http::response(['reason' => 'BadDeviceToken'], 400),
        ]);
        $rung = $this->rung();
        $android = Device::create(['user_id' => $rung->user_id, 'platform' => 'android', 'api_token_hash' => 'h1', 'push_token' => 'fcm-1']);
        $iphone = Device::create(['user_id' => $rung->user_id, 'platform' => 'ios', 'api_token_hash' => 'h2', 'push_token' => 'apns-dead']);
        $windows = Device::create(['user_id' => $rung->user_id, 'platform' => 'windows', 'api_token_hash' => 'h3', 'push_token' => 'n/a']);

        $router = new DeviceRouter(
            new ApnsSender('TEAM', 'K1', $ec, 'com.stanchion.guard'),
            new FcmSender(['project_id' => 'p', 'client_email' => 'e@x', 'private_key' => $rsa]),
        );
        $id = $router->sendRung($rung);

        $this->assertSame('projects/p/messages/1', $id);
        $this->assertTrue($android->fresh()->token_valid);
        $this->assertFalse($iphone->fresh()->token_valid);
        $this->assertSame('invalid', $iphone->fresh()->notif_state);
        $this->assertTrue($windows->fresh()->token_valid, 'windows is untouched until M5');
    }
}
