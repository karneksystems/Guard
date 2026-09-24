<?php

namespace Tests\Feature;

use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\Device;
use App\Models\Instrument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class ApiTest extends TestCase
{
    use RefreshDatabase;

    private function registered(): array
    {
        $response = $this->postJson('/api/devices', ['platform' => 'android', 'tz' => 'Europe/London', 'app_version' => '0.1.0']);
        $response->assertCreated();

        return [$response->json('deviceId'), $response->json('token')];
    }

    public function test_registration_issues_a_token_and_creates_defaults(): void
    {
        [$deviceId, $token] = $this->registered();

        $device = Device::findByToken($token);
        $this->assertNotNull($device);
        $this->assertSame($deviceId, $device->id);
        $this->assertSame('conservative', $device->user->settings->mode);
        $this->assertSame(5, $device->user->settings->window_before_min);
        $this->assertNotNull($device->user->profile);
        $this->assertSame('private', $device->user->profile->visibility);
    }

    public function test_sync_requires_a_token(): void
    {
        $this->getJson('/api/sync')->assertUnauthorized();
        $this->withToken('nope')->getJson('/api/sync')->assertUnauthorized();
    }

    public function test_free_user_is_capped_at_two_instruments_and_fixed_window(): void
    {
        Queue::fake();
        [, $token] = $this->registered();

        $this->withToken($token)->putJson('/api/instruments', ['instruments' => [
            ['symbol' => 'XAUUSD', 'basket' => ['USD', 'EUR', 'GBP']],
            ['symbol' => 'EURUSD', 'basket' => ['EUR', 'USD']],
            ['symbol' => 'GBPJPY', 'basket' => ['GBP', 'JPY']],
        ]])->assertOk()->assertJson(['count' => 2]);
        $this->assertSame(2, Instrument::count());

        $this->withToken($token)->putJson('/api/settings', ['window_before_min' => 2, 'window_after_min' => 2, 'protection' => 'hard-block'])
            ->assertOk()
            ->assertJsonPath('settings.window_before_min', 5)
            ->assertJsonPath('settings.protection', 'soft-gate');

        // ReconcileUserLadder is ShouldBeUnique, so back-to-back pushes collapse into one.
        Queue::assertPushed(ReconcileUserLadder::class);
    }

    public function test_sync_returns_the_shapes_the_app_expects(): void
    {
        [, $token] = $this->registered();

        $this->withToken($token)->getJson('/api/sync')
            ->assertOk()
            ->assertJsonStructure(['serverTimeUtc', 'pro', 'settings', 'instruments', 'events', 'windows', 'ladder'])
            ->assertJsonPath('pro', false);
    }

    public function test_packs_index_lists_the_seed_packs_as_unverified(): void
    {
        $this->getJson('/api/packs')->assertOk()->assertJsonPath('packs.0.firmId', 'alpha-capital')->assertJsonPath('packs.0.needsReverify', true);
        $this->getJson('/api/packs/ftmo')->assertOk()->assertJsonPath('firmName', 'FTMO');
        $this->getJson('/api/packs/nope')->assertNotFound();
    }

    public function test_journal_entry_is_recorded(): void
    {
        [, $token] = $this->registered();
        $this->withToken($token)->postJson('/api/journal', ['window_id' => str_repeat('a', 20), 'outcome' => 'stayed-out', 'at_utc' => now()->subMinute()->toIso8601String()])
            ->assertCreated();
        // A time far in the future or a window id with odd characters is refused.
        $this->withToken($token)->postJson('/api/journal', ['window_id' => str_repeat('a', 20), 'outcome' => 'stayed-out', 'at_utc' => '2099-01-01T00:00:00Z'])
            ->assertUnprocessable();
        $this->withToken($token)->postJson('/api/journal', ['window_id' => str_repeat('A', 20), 'outcome' => 'stayed-out', 'at_utc' => now()->toIso8601String()])
            ->assertUnprocessable();
    }
}
