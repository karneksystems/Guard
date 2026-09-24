<?php

namespace Tests\Feature;

use Tests\TestCase;

final class HealthTest extends TestCase
{
    use \Illuminate\Foundation\Testing\RefreshDatabase;

    public function test_root_names_the_service(): void
    {
        $this->getJson('/')->assertOk()->assertJsonPath('service', 'guard');
    }

    public function test_root_reports_the_calendar_age(): void
    {
        $this->getJson('/')->assertOk()->assertJsonPath('calendarFetchedAt', null);
        \App\Models\CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => 'x', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high',
            'scheduled_at_utc' => new \DateTimeImmutable('2026-10-02T12:30:00', new \DateTimeZone('UTC')),
            'tentative' => false, 'source' => 'fake', 'fetched_at' => new \DateTimeImmutable('2026-09-24T10:00:00', new \DateTimeZone('UTC')),
        ]);
        $this->assertNotNull($this->getJson('/')->json('calendarFetchedAt'));
    }

    public function test_health_endpoint_is_up(): void
    {
        $this->get('/up')->assertOk();
    }
}
