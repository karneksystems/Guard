<?php

namespace Tests\Feature;

use App\Ladder\QuietHours;
use App\Models\Device;
use App\Models\Instrument;
use App\Models\User;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class AccountAndQuietHoursTest extends TestCase
{
    use RefreshDatabase;

    private function token(): string
    {
        return $this->postJson('/api/devices', ['platform' => 'android', 'tz' => 'Europe/London', 'app_version' => '0.1.0'])->json('token');
    }

    public function test_deleting_the_account_removes_every_row_and_the_token_stops_working(): void
    {
        Queue::fake();
        $token = $this->token();
        $this->withToken($token)->putJson('/api/instruments', ['instruments' => [['symbol' => 'XAUUSD', 'basket' => ['USD']]]])->assertOk();
        $userId = Device::findByToken($token)->user_id;

        $this->withToken($token)->deleteJson('/api/account')->assertOk()->assertJson(['ok' => true]);

        $this->assertNull(User::find($userId));
        $this->assertNull(Device::findByToken($token));
        $this->assertSame(0, Instrument::query()->where('user_id', $userId)->count());
        $this->withToken($token)->getJson('/api/sync')->assertUnauthorized();
    }

    public function test_quiet_hours_are_validated_as_a_start_and_end(): void
    {
        Queue::fake();
        $token = $this->token();
        $this->withToken($token)->putJson('/api/settings', ['quiet_hours' => ['start' => '23:00', 'end' => '06:00']])->assertOk();
        $this->withToken($token)->putJson('/api/settings', ['quiet_hours' => ['start' => 'late']])->assertUnprocessable();
        $this->withToken($token)->putJson('/api/settings', ['quiet_hours' => null])->assertOk();
    }

    public function test_quiet_hours_silence_the_soft_rungs_only_and_cross_midnight(): void
    {
        $q = QuietHours::fromSettings(['start' => '23:00', 'end' => '06:00'], 'Europe/London');
        $utc = new DateTimeZone('UTC');
        // 02:30 London in September is 01:30 UTC: inside.
        $inside = new DateTimeImmutable('2026-09-25T01:30:00', $utc);
        $outside = new DateTimeImmutable('2026-09-25T08:30:00', $utc);

        $this->assertTrue($q->silences('t-60', $inside));
        $this->assertTrue($q->silences('t-15', $inside));
        $this->assertTrue($q->silences('end', $inside));
        $this->assertFalse($q->silences('t-5', $inside));
        $this->assertFalse($q->silences('t-1', $inside));
        $this->assertFalse($q->silences('open', $inside));
        $this->assertFalse($q->silences('t-60', $outside));

        // 22:45 UTC is 23:45 London: inside; 22:30 UTC is 23:30 London: inside; 21:30 UTC is 22:30 London: outside.
        $this->assertTrue($q->contains(new DateTimeImmutable('2026-09-25T22:45:00', $utc)));
        $this->assertFalse($q->contains(new DateTimeImmutable('2026-09-25T21:30:00', $utc)));
        $this->assertNull(QuietHours::fromSettings(null, 'UTC'));
    }
}
