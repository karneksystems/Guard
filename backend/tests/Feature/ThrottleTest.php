<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class ThrottleTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_is_rate_limited_per_address(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/devices', ['platform' => 'android'])->assertCreated();
        }
        $this->postJson('/api/devices', ['platform' => 'android'])->assertStatus(429);
    }
}
