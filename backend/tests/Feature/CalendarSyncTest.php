<?php

namespace Tests\Feature;

use App\Calendar\CalendarSync;
use App\Calendar\FakeVendor;
use App\Events\CalendarEventChanged;
use App\Models\CalendarEvent;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

final class CalendarSyncTest extends TestCase
{
    use RefreshDatabase;

    private function window(): array
    {
        $tz = new DateTimeZone('UTC');

        return [new DateTimeImmutable('2026-10-01T00:00:00', $tz), new DateTimeImmutable('2026-10-15T00:00:00', $tz)];
    }

    public function test_first_sync_creates_events_and_second_sync_is_idempotent(): void
    {
        Event::fake([CalendarEventChanged::class]);
        $vendor = new FakeVendor();
        $vendor->setEvents([
            ['vendorId' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high', 'scheduledAtUtc' => '2026-10-02T12:30:00Z'],
            ['vendorId' => 'cpi', 'currency' => 'EUR', 'title' => 'CPI', 'impact' => 'high', 'scheduledAtUtc' => '2026-10-01T09:00:00Z'],
        ]);
        $sync = new CalendarSync($vendor);
        [$from, $to] = $this->window();

        $this->assertSame(['created' => 2, 'changed' => 0, 'unchanged' => 0, 'removed' => 0], $sync->sync($from, $to));
        $this->assertSame(['created' => 0, 'changed' => 0, 'unchanged' => 2, 'removed' => 0], $sync->sync($from, $to));
        $this->assertSame(2, CalendarEvent::count());
        Event::assertNotDispatched(CalendarEventChanged::class);
    }

    public function test_a_moved_event_records_the_old_time_and_dispatches_a_change(): void
    {
        Event::fake([CalendarEventChanged::class]);
        $vendor = new FakeVendor();
        $vendor->setEvents([['vendorId' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high', 'scheduledAtUtc' => '2026-10-02T12:30:00Z']]);
        $sync = new CalendarSync($vendor);
        [$from, $to] = $this->window();
        $sync->sync($from, $to);

        $vendor->setEvents([['vendorId' => 'nfp', 'currency' => 'USD', 'title' => 'NFP', 'impact' => 'high', 'scheduledAtUtc' => '2026-10-02T13:30:00Z']]);
        $this->assertSame(['created' => 0, 'changed' => 1, 'unchanged' => 0, 'removed' => 0], $sync->sync($from, $to));

        $event = CalendarEvent::query()->where('vendor_id', 'nfp')->firstOrFail();
        $this->assertSame('2026-10-02T13:30:00Z', $event->scheduled_at_utc->format('Y-m-d\TH:i:s\Z'));
        $this->assertSame('2026-10-02T12:30:00Z', $event->revised_from_utc->format('Y-m-d\TH:i:s\Z'));
        Event::assertDispatched(CalendarEventChanged::class, fn (CalendarEventChanged $e) => $e->previouslyScheduledAtUtc->format('H:i') === '12:30');
    }

    public function test_events_outside_the_requested_window_are_ignored(): void
    {
        $vendor = new FakeVendor();
        $vendor->setEvents([['vendorId' => 'far', 'currency' => 'USD', 'title' => 'Far', 'impact' => 'high', 'scheduledAtUtc' => '2027-01-01T00:00:00Z']]);
        [$from, $to] = $this->window();

        $this->assertSame(['created' => 0, 'changed' => 0, 'unchanged' => 0, 'removed' => 0], (new CalendarSync($vendor))->sync($from, $to));
    }
}
