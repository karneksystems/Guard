<?php

namespace Tests\Feature;

use App\Calendar\CalendarSync;
use App\Calendar\FakeVendor;
use App\Ladder\EngineInputBuilder;
use App\Ladder\Jobs\SendRung;
use App\Ladder\LadderReconciler;
use App\Models\CalendarEvent;
use App\Models\Device;
use App\Models\Instrument;
use App\Models\Rung;
use App\Models\Setting;
use App\Models\User;
use App\Push\PushSender;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class ReviewHardeningTest extends TestCase
{
    use RefreshDatabase;

    private function utc(string $s): DateTimeImmutable
    {
        return new DateTimeImmutable($s, new DateTimeZone('UTC'));
    }

    private function goldUser(): User
    {
        $user = User::create(['tz' => 'UTC']);
        Setting::create(['user_id' => $user->id]);
        Instrument::create(['user_id' => $user->id, 'symbol' => 'XAUUSD', 'basket_currencies' => ['USD']]);

        return $user;
    }

    private function nfp(string $at): CalendarEvent
    {
        return CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high',
            'scheduled_at_utc' => $this->utc($at), 'tentative' => false, 'source' => 'fake', 'fetched_at' => $this->utc($at),
        ]);
    }

    public function test_send_rung_sends_exactly_once_under_a_duplicate_job(): void
    {
        $user = $this->goldUser();
        Rung::create(['alert_id' => str_repeat('a', 20), 'user_id' => $user->id, 'window_id' => str_repeat('w', 20), 'kind' => 'open', 'fire_at_utc' => $this->utc('2026-10-02T12:25:00')]);
        $sends = 0;
        $sender = new class($sends) implements PushSender {
            public function __construct(private int &$sends)
            {
            }

            public function sendRung(Rung $rung): ?string
            {
                $this->sends++;

                return 'id';
            }

            public function sendResync(int $userId): void
            {
            }
        };
        (new SendRung(str_repeat('a', 20)))->handle($sender);
        (new SendRung(str_repeat('a', 20)))->handle($sender);
        $this->assertSame(1, $sends);
        $this->assertSame(Rung::SENT, Rung::query()->find(str_repeat('a', 20))->state);
    }

    public function test_an_event_moved_and_moved_back_revives_the_cancelled_rungs(): void
    {
        Queue::fake();
        $user = $this->goldUser();
        $event = $this->nfp('2026-10-02T12:30:00');
        $reconciler = new LadderReconciler(app(EngineInputBuilder::class), 48);
        $now = $this->utc('2026-10-02T06:00:00');

        $first = $reconciler->reconcile($user, $now);
        $this->assertSame(6, $first['created']);
        $ids = Rung::query()->where('state', Rung::SCHEDULED)->pluck('alert_id')->sort()->values()->all();

        $event->forceFill(['scheduled_at_utc' => $this->utc('2026-10-02T13:30:00')])->save();
        $moved = $reconciler->reconcile($user, $now);
        $this->assertSame(6, $moved['cancelled']);

        $event->forceFill(['scheduled_at_utc' => $this->utc('2026-10-02T12:30:00')])->save();
        $back = $reconciler->reconcile($user, $now);
        $this->assertSame(6, $back['created'], 'the original ids come back to life');
        $this->assertSame($ids, Rung::query()->where('state', Rung::SCHEDULED)->pluck('alert_id')->sort()->values()->all());
    }

    public function test_rungs_already_in_the_past_are_not_created_except_open_inside_the_window(): void
    {
        Queue::fake();
        $user = $this->goldUser();
        $this->nfp('2026-10-02T12:30:00');
        $reconciler = new LadderReconciler(app(EngineInputBuilder::class), 48);

        // Three minutes before the event the window (12:25 to 12:35) is already open:
        // t-60, t-15, t-5 and t-1 are history, open fires now because it is still
        // news, end stays. Four pushes saying "window in 60 min" would have gone out.
        $r = $reconciler->reconcile($user, $this->utc('2026-10-02T12:27:00'));
        $this->assertSame(2, $r['created']);
        $this->assertSame(['end', 'open'], Rung::query()->pluck('kind')->sort()->values()->all());

        Rung::query()->delete();
        // Ten minutes before: t-60 and t-15 are gone, t-5, t-1, open and end remain.
        $r = $reconciler->reconcile($user, $this->utc('2026-10-02T12:20:00'));
        $this->assertSame(['end', 'open', 't-1', 't-5'], Rung::query()->pluck('kind')->sort()->values()->all());

        Rung::query()->delete();
        // Inside the window: open fires now (it is news), end is the only other one.
        $r = $reconciler->reconcile($user, $this->utc('2026-10-02T12:31:00'));
        $this->assertSame(['end', 'open'], Rung::query()->pluck('kind')->sort()->values()->all());
    }

    public function test_an_expired_pro_user_is_clamped_to_free_on_read_and_in_the_engine(): void
    {
        $user = User::create(['tz' => 'UTC', 'pro_until' => now()->subDay()]);
        Setting::create(['user_id' => $user->id, 'mode' => 'firm-match', 'firm_id' => 'ftmo', 'account_type_id' => 'ftmo-account', 'protection' => 'hard-block', 'window_before_min' => 30, 'window_after_min' => 30]);
        foreach (['XAUUSD', 'EURUSD', 'GBPUSD'] as $s) {
            Instrument::create(['user_id' => $user->id, 'symbol' => $s, 'basket_currencies' => ['USD']]);
        }
        $clamped = EngineInputBuilder::clampSettings($user);
        $this->assertSame('conservative', $clamped['mode']);
        $this->assertSame('soft-gate', $clamped['protection']);
        $this->assertSame(5, $clamped['window_before_min']);
        $this->assertNull($clamped['firm_id']);

        $input = app(EngineInputBuilder::class)->build($user, $this->utc('2026-10-02T00:00:00'), $this->utc('2026-10-03T00:00:00'));
        $this->assertSame('conservative', $input['settings']['mode']);
        $this->assertCount(2, $input['instruments']);
        $this->assertArrayNotHasKey('packId', $input);
    }

    public function test_a_receipt_bound_to_one_account_is_refused_from_another(): void
    {
        config(['guard.receipt_verifier' => 'fake']);
        Queue::fake();
        $a = $this->postJson('/api/devices', ['platform' => 'android'])->json('token');
        $b = $this->postJson('/api/devices', ['platform' => 'ios'])->json('token');
        $this->withToken($a)->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:monthly:tx-1'])->assertOk();
        $this->withToken($b)->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:monthly:tx-1'])->assertStatus(409);
        $this->withToken($a)->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:monthly:tx-1'])->assertOk();
        $this->assertFalse(Device::findByToken($b)->user->isPro());
    }

    public function test_firm_match_needs_a_firm_and_an_account_type_in_the_merged_state(): void
    {
        Queue::fake();
        $token = $this->postJson('/api/devices', ['platform' => 'android'])->json('token');
        Device::findByToken($token)->user->forceFill(['pro_until' => now()->addMonth()])->save();
        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match'])->assertUnprocessable();
        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match', 'firm_id' => 'ftmo'])->assertUnprocessable();
        $this->withToken($token)->putJson('/api/settings', ['firm_id' => 'ftmo', 'account_type_id' => 'ftmo-account'])->assertOk();
        $this->withToken($token)->putJson('/api/settings', ['mode' => 'firm-match'])->assertOk();
        $this->withToken($token)->patchJson('/api/device', ['tz' => 'Mars/Olympus'])->assertUnprocessable();
        $this->withToken($token)->patchJson('/api/device', ['tz' => 'Europe/London'])->assertOk();
        $this->assertSame('Europe/London', Device::findByToken($token)->user->fresh()->tz);
    }

    public function test_an_event_that_vanishes_from_the_feed_is_marked_removed_and_no_longer_served(): void
    {
        $vendor = new FakeVendor();
        $vendor->setEvents([
            ['vendorId' => 'a', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high', 'scheduledAtUtc' => $this->utc('2026-10-02T12:30:00'), 'tentative' => false, 'source' => 'fake'],
            ['vendorId' => 'b', 'currency' => 'EUR', 'title' => 'CPI', 'impact' => 'high', 'scheduledAtUtc' => $this->utc('2026-10-02T09:00:00'), 'tentative' => false, 'source' => 'fake'],
        ]);
        $from = $this->utc('2026-10-01T00:00:00');
        $to = $this->utc('2026-10-03T00:00:00');
        (new CalendarSync($vendor))->sync($from, $to);

        $only = new FakeVendor();
        $only->setEvents([
            ['vendorId' => 'a', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high', 'scheduledAtUtc' => $this->utc('2026-10-02T12:30:00'), 'tentative' => false, 'source' => 'fake'],
        ]);
        $r = (new CalendarSync($only))->sync($from, $to);
        $this->assertSame(1, $r['removed']);
        $this->assertNotNull(CalendarEvent::query()->where('vendor_id', 'b')->first()->removed_at);

        $user = $this->goldUser();
        $input = app(EngineInputBuilder::class)->build($user, $from, $to);
        $this->assertSame(['NFP'], array_column($input['events'], 'title'));

        // Back in the feed: alive again.
        (new CalendarSync($vendor))->sync($from, $to);
        $this->assertNull(CalendarEvent::query()->where('vendor_id', 'b')->first()->removed_at);
    }
}
