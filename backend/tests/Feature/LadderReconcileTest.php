<?php

namespace Tests\Feature;

use App\Ladder\Jobs\SendRung;
use App\Ladder\LadderReconciler;
use App\Models\CalendarEvent;
use App\Models\Instrument;
use App\Models\Rung;
use App\Models\Setting;
use App\Models\User;
use App\Models\Window;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class LadderReconcileTest extends TestCase
{
    use RefreshDatabase;

    private DateTimeImmutable $now;

    protected function setUp(): void
    {
        parent::setUp();
        $this->now = new DateTimeImmutable('2026-10-02T06:00:00', new DateTimeZone('UTC'));
        Queue::fake();
    }

    private function goldUser(): User
    {
        $user = User::create(['tz' => 'Europe/London']);
        Setting::create(['user_id' => $user->id]);
        Instrument::create(['user_id' => $user->id, 'symbol' => 'XAUUSD', 'basket_currencies' => ['USD', 'EUR', 'GBP']]);

        return $user;
    }

    private function nfp(string $at = '2026-10-02T12:30:00Z'): CalendarEvent
    {
        return CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high',
            'scheduled_at_utc' => new DateTimeImmutable($at, new DateTimeZone('UTC')), 'source' => 'fake',
        ]);
    }

    public function test_first_reconcile_creates_one_window_and_six_rungs(): void
    {
        $user = $this->goldUser();
        $this->nfp();

        $counts = app(LadderReconciler::class)->reconcile($user, $this->now);

        $this->assertSame(['created' => 6, 'cancelled' => 0, 'kept' => 0, 'windows' => 1], $counts);
        $window = Window::query()->where('user_id', $user->id)->firstOrFail();
        $this->assertSame('2026-10-02T12:25:00Z', $window->opens_at_utc->format('Y-m-d\TH:i:s\Z'));
        $this->assertSame('2026-10-02T12:35:00Z', $window->closes_at_utc->format('Y-m-d\TH:i:s\Z'));
        $this->assertSame(['t-60', 't-15', 't-5', 't-1', 'open', 'end'], Rung::query()->orderBy('fire_at_utc')->pluck('kind')->all());
        Queue::assertPushed(SendRung::class, 6);
        Queue::assertPushed(SendRung::class, fn (SendRung $job) => $job->queue === 'ladder' && $job->delay !== null);
    }

    public function test_second_reconcile_keeps_everything_and_pushes_nothing(): void
    {
        $user = $this->goldUser();
        $this->nfp();
        $reconciler = app(LadderReconciler::class);
        $reconciler->reconcile($user, $this->now);

        $counts = $reconciler->reconcile($user, $this->now);

        $this->assertSame(['created' => 0, 'cancelled' => 0, 'kept' => 6, 'windows' => 1], $counts);
        Queue::assertPushed(SendRung::class, 6);
    }

    public function test_a_moved_event_cancels_the_old_rungs_and_creates_new_ones(): void
    {
        $user = $this->goldUser();
        $event = $this->nfp();
        $reconciler = app(LadderReconciler::class);
        $reconciler->reconcile($user, $this->now);
        $oldIds = Rung::query()->pluck('alert_id')->all();

        $event->forceFill(['scheduled_at_utc' => new DateTimeImmutable('2026-10-02T13:30:00Z', new DateTimeZone('UTC'))])->save();
        $counts = $reconciler->reconcile($user, $this->now);

        $this->assertSame(['created' => 6, 'cancelled' => 6, 'kept' => 0, 'windows' => 1], $counts);
        $this->assertSame(6, Rung::query()->whereIn('alert_id', $oldIds)->where('state', Rung::CANCELLED)->count());
        $this->assertSame(6, Rung::query()->where('state', Rung::SCHEDULED)->count());
        $this->assertSame(0, count(array_intersect($oldIds, Rung::query()->where('state', Rung::SCHEDULED)->pluck('alert_id')->all())));
    }

    public function test_a_sent_rung_is_never_recreated_or_cancelled(): void
    {
        $user = $this->goldUser();
        $this->nfp();
        $reconciler = app(LadderReconciler::class);
        $reconciler->reconcile($user, $this->now);
        $sent = Rung::query()->where('kind', 't-60')->firstOrFail();
        $sent->forceFill(['state' => Rung::SENT, 'provider_msg_id' => 'x'])->save();

        $counts = $reconciler->reconcile($user, $this->now);

        $this->assertSame(['created' => 0, 'cancelled' => 0, 'kept' => 5, 'windows' => 1], $counts);
        $this->assertSame(Rung::SENT, $sent->fresh()->state);
    }

    public function test_free_user_with_no_matching_currency_gets_no_windows(): void
    {
        $user = $this->goldUser();
        CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'boj', 'currency' => 'JPY', 'title' => 'BoJ', 'impact' => 'high',
            'scheduled_at_utc' => new DateTimeImmutable('2026-10-02T03:00:00Z', new DateTimeZone('UTC')), 'source' => 'fake',
        ]);

        $counts = app(LadderReconciler::class)->reconcile($user, $this->now);

        $this->assertSame(['created' => 0, 'cancelled' => 0, 'kept' => 0, 'windows' => 0], $counts);
        Queue::assertNothingPushed();
    }
}
