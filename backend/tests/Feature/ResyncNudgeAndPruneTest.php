<?php

namespace Tests\Feature;

use App\Ladder\Jobs\ReconcileUserLadder;
use App\Ladder\Jobs\SendResyncNudge;
use App\Ladder\LadderReconciler;
use App\Models\CalendarEvent;
use App\Models\Device;
use App\Models\Instrument;
use App\Models\Rung;
use App\Models\Setting;
use App\Models\User;
use App\Models\Window;
use App\Push\ApnsSender;
use App\Push\DeviceRouter;
use App\Push\FcmSender;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class ResyncNudgeAndPruneTest extends TestCase
{
    use RefreshDatabase;

    private function utc(string $s): DateTimeImmutable
    {
        return new DateTimeImmutable($s, new DateTimeZone('UTC'));
    }

    public function test_a_reconcile_that_changes_rungs_nudges_the_devices_and_a_quiet_one_does_not(): void
    {
        Queue::fake();
        $user = User::create(['tz' => 'UTC']);
        Setting::create(['user_id' => $user->id]);
        Instrument::create(['user_id' => $user->id, 'symbol' => 'XAUUSD', 'basket_currencies' => ['USD']]);
        // The job reconciles against the real clock, so the event sits six hours out.
        $now = \App\Ladder\EngineInputBuilder::utcNow();
        CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high',
            'scheduled_at_utc' => $now->modify('+6 hours'), 'tentative' => false, 'source' => 'fake', 'fetched_at' => $now,
        ]);
        $reconciler = new LadderReconciler(app(\App\Ladder\EngineInputBuilder::class), 48);

        (new ReconcileUserLadder($user->id))->handle($reconciler);
        Queue::assertPushed(SendResyncNudge::class, 1);

        (new ReconcileUserLadder($user->id))->handle($reconciler);
        Queue::assertPushed(SendResyncNudge::class, 1);
    }

    public function test_the_router_sends_a_silent_push_per_platform_and_prunes_a_dead_token(): void
    {
        $user = User::create(['tz' => 'UTC']);
        Device::create(['user_id' => $user->id, 'platform' => 'ios', 'api_token_hash' => 'a', 'push_token' => 'ios-tok', 'token_valid' => true]);
        Device::create(['user_id' => $user->id, 'platform' => 'android', 'api_token_hash' => 'b', 'push_token' => 'and-tok', 'token_valid' => true]);
        $dead = Device::create(['user_id' => $user->id, 'platform' => 'android', 'api_token_hash' => 'c', 'push_token' => 'dead-tok', 'token_valid' => true]);

        Http::fake([
            'https://api.push.apple.com/*' => Http::response('', 200, ['apns-id' => 'x']),
            'https://oauth2.googleapis.com/*' => Http::response(['access_token' => 't'], 200),
            'https://fcm.googleapis.com/*' => function (Request $r) {
                $token = $r->data()['message']['token'];

                return $token === 'dead-tok'
                    ? Http::response(['error' => ['status' => 'NOT_FOUND']], 404)
                    : Http::response(['name' => 'ok'], 200);
            },
        ]);
        $key = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_EC, 'curve_name' => 'prime256v1']);
        openssl_pkey_export($key, $ecPem);
        $rsa = openssl_pkey_new(['private_key_type' => OPENSSL_KEYTYPE_RSA, 'private_key_bits' => 2048]);
        openssl_pkey_export($rsa, $rsaPem);

        $router = new DeviceRouter(
            new ApnsSender(teamId: 'T', keyId: 'K', privateKeyPem: $ecPem, bundleId: 'com.test', sandbox: false),
            new FcmSender(['project_id' => 'p', 'client_email' => 'e@x', 'private_key' => $rsaPem]),
        );
        $router->sendResync($user->id);

        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'api.push.apple.com')
            && $r->header('apns-push-type')[0] === 'background'
            && $r->data()['aps']['content-available'] === 1
            && $r->data()['type'] === 'resync');
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'fcm.googleapis.com')
            && ($r->data()['message']['data']['type'] ?? null) === 'resync'
            && !isset($r->data()['message']['notification']));
        $this->assertFalse($dead->fresh()->token_valid);
    }

    public function test_settings_refuse_unknown_firms_and_account_types(): void
    {
        Queue::fake();
        $token = $this->postJson('/api/devices', ['platform' => 'android'])->json('token');
        $user = Device::findByToken($token)->user;
        $user->forceFill(['pro_until' => now()->addMonth()])->save();

        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match', 'firm_id' => 'nobody'])->assertUnprocessable();
        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match', 'firm_id' => 'ftmo', 'account_type_id' => 'made-up'])->assertUnprocessable();
        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match', 'firm_id' => 'ftmo', 'account_type_id' => 'ftmo-account'])->assertOk();
    }

    public function test_prune_drops_old_derived_rows_and_keeps_the_rest(): void
    {
        $user = User::create(['tz' => 'UTC']);
        $mk = function (string $id, string $closes, string $state) use ($user) {
            Window::create(['id' => $id, 'user_id' => $user->id, 'instrument' => 'XAUUSD', 'opens_at_utc' => $this->utc($closes)->modify('-10 minutes'), 'closes_at_utc' => $this->utc($closes), 'reasons' => [], 'verified' => true]);
            Rung::create(['alert_id' => 'r' . $id, 'user_id' => $user->id, 'window_id' => $id, 'kind' => 'open', 'fire_at_utc' => $this->utc($closes), 'state' => $state]);
        };
        $mk(str_repeat('a', 20), '2026-09-01T12:00:00', Rung::SENT);
        $mk(str_repeat('b', 20), '2026-09-23T12:00:00', Rung::SENT);
        $mk(str_repeat('c', 20), '2026-09-01T12:00:00', Rung::SCHEDULED);
        CalendarEvent::create(['vendor' => 'fake', 'vendor_id' => 'old', 'currency' => 'USD', 'title' => 'Old', 'impact' => 'high', 'scheduled_at_utc' => $this->utc('2026-08-01T12:00:00'), 'tentative' => false, 'source' => 'fake']);
        CalendarEvent::create(['vendor' => 'fake', 'vendor_id' => 'new', 'currency' => 'USD', 'title' => 'New', 'impact' => 'high', 'scheduled_at_utc' => $this->utc('2026-09-20T12:00:00'), 'tentative' => false, 'source' => 'fake']);

        $this->travelTo($this->utc('2026-09-24T12:00:00'));
        $this->artisan('guard:prune')->assertSuccessful();

        // The scheduled rung from 1 September never fired: stuck, logged, gone.
        $this->assertSame(['r' . str_repeat('b', 20)], Rung::query()->orderBy('alert_id')->pluck('alert_id')->all());
        $this->assertSame([str_repeat('b', 20)], Window::query()->pluck('id')->all());
        $this->assertSame(['New'], CalendarEvent::query()->pluck('title')->all());
    }
}
