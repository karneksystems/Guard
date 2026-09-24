<?php

namespace Tests\Feature;

use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\Device;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

final class EntitlementTest extends TestCase
{
    use RefreshDatabase;

    private function token(): string
    {
        return $this->postJson('/api/devices', ['platform' => 'android', 'tz' => 'UTC', 'app_version' => '0.1.0'])->json('token');
    }

    public function test_default_verifier_rejects_everything(): void
    {
        $token = $this->token();
        $this->withToken($token)
            ->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:monthly'])
            ->assertStatus(402)
            ->assertJson(['ok' => false]);
        $this->withToken($token)->getJson('/api/sync')->assertOk()->assertJson(['pro' => false, 'proUntil' => null]);
    }

    public function test_fake_verifier_grants_pro_and_sync_reports_it(): void
    {
        config(['guard.receipt_verifier' => 'fake']);
        Queue::fake();
        $token = $this->token();

        $r = $this->withToken($token)
            ->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'yearly', 'receipt' => 'fake:yearly'])
            ->assertOk()
            ->assertJson(['ok' => true]);
        $this->assertNotNull($r->json('proUntil'));
        Queue::assertPushed(ReconcileUserLadder::class);

        $sync = $this->withToken($token)->getJson('/api/sync')->assertOk();
        $this->assertTrue($sync->json('pro'));
        $this->assertSame($r->json('proUntil'), $sync->json('proUntil'));

        // A shorter receipt never shortens what the user holds.
        $again = $this->withToken($token)
            ->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:monthly'])
            ->assertOk();
        $this->assertSame($r->json('proUntil'), $again->json('proUntil'));

        $device = Device::findByToken($token);
        $this->assertTrue($device->user->fresh()->isPro());
    }

    public function test_wrong_receipt_is_rejected_even_on_the_fake_verifier(): void
    {
        config(['guard.receipt_verifier' => 'fake']);
        $token = $this->token();
        $this->withToken($token)
            ->postJson('/api/entitlement', ['platform' => 'apple', 'plan' => 'monthly', 'receipt' => 'fake:monthly'])
            ->assertStatus(402);
        $this->withToken($token)
            ->postJson('/api/entitlement', ['platform' => 'fake', 'plan' => 'monthly', 'receipt' => 'fake:yearly'])
            ->assertStatus(402);
    }
}
