<?php

namespace Tests\Feature;

use Tests\TestCase;

final class HealthTest extends TestCase
{
    public function test_root_names_the_service(): void
    {
        $this->getJson('/')->assertOk()->assertJsonPath('service', 'guard');
    }

    public function test_health_endpoint_is_up(): void
    {
        $this->get('/up')->assertOk();
    }
}
