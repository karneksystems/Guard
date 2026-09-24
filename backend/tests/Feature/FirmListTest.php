<?php

namespace Tests\Feature;

use App\FirmLists\FirmListImporter;
use App\Ladder\EngineInputBuilder;
use App\Models\CalendarEvent;
use App\Models\FirmListEvent;
use App\Models\Instrument;
use App\Models\Setting;
use App\Models\User;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class FirmListTest extends TestCase
{
    use RefreshDatabase;

    private function event(string $currency, string $title, string $at, string $impact = 'high'): CalendarEvent
    {
        return CalendarEvent::create([
            'vendor' => 'fake', 'vendor_id' => md5($title . $at), 'currency' => $currency, 'title' => $title,
            'impact' => $impact, 'scheduled_at_utc' => new DateTimeImmutable($at, new DateTimeZone('UTC')),
            'tentative' => false, 'source' => 'fake', 'fetched_at' => new DateTimeImmutable('now', new DateTimeZone('UTC')),
        ]);
    }

    public function test_rows_match_by_currency_time_and_title_words_and_reimport_replaces(): void
    {
        $nfp = $this->event('USD', 'Non-Farm Employment Change', '2026-10-02T12:30:00Z');
        $claims = $this->event('USD', 'Unemployment Claims', '2026-10-02T12:30:00Z');
        $this->event('EUR', 'CPI Flash Estimate y/y', '2026-10-01T09:00:00Z');

        $importer = new FirmListImporter();
        $r = $importer->import('ftmo', [
            ['currency' => 'USD', 'title' => 'Nonfarm Payrolls', 'scheduledAtUtc' => '2026-10-02T12:30:00Z'],
            ['currency' => 'usd', 'title' => 'Initial Jobless Claims', 'scheduledAtUtc' => '2026-10-02T12:31:00Z'],
            ['currency' => 'GBP', 'title' => 'BoE Rate', 'scheduledAtUtc' => '2026-10-02T11:00:00Z'],
        ], 'test');

        $this->assertSame(3, $r['imported']);
        $this->assertSame(2, $r['matched']);
        $this->assertCount(1, $r['unmatched']);
        $this->assertStringContainsString('BoE Rate', $r['unmatched'][0]);

        $rows = FirmListEvent::query()->where('firm_id', 'ftmo')->orderBy('id')->get();
        // Two candidates at 12:30: "Nonfarm" matches "Non-Farm" once hyphens are dropped,
        // and "Claims" picks the other.
        $this->assertSame($nfp->id, $rows[0]->calendar_event_id);
        $this->assertSame($claims->id, $rows[1]->calendar_event_id);
        $this->assertNull($rows[2]->calendar_event_id);

        // Re-import for the same day replaces, never duplicates.
        $importer->import('ftmo', [
            ['currency' => 'USD', 'title' => 'Non-Farm Employment', 'scheduledAtUtc' => '2026-10-02T12:30:00Z'],
        ], 'test');
        $again = FirmListEvent::query()->where('firm_id', 'ftmo')->get();
        $this->assertCount(1, $again);
        $this->assertSame($nfp->id, $again->first()->calendar_event_id);
    }

    public function test_single_candidate_at_the_same_minute_matches_despite_different_naming(): void
    {
        $nfp = $this->event('USD', 'Non-Farm Employment Change', '2026-10-02T12:30:00Z');
        $r = (new FirmListImporter())->import('ftmo', [
            ['currency' => 'USD', 'title' => 'NFP', 'scheduledAtUtc' => '2026-10-02T12:30:00Z'],
        ], 'test');
        $this->assertSame(1, $r['matched']);
        $this->assertSame($nfp->id, FirmListEvent::query()->first()->calendar_event_id);
    }

    public function test_engine_input_carries_the_matched_ids_for_a_firm_match_user(): void
    {
        $nfp = $this->event('USD', 'Non-Farm Employment Change', '2026-10-02T12:30:00Z');
        $this->event('USD', 'Chicago PMI', '2026-10-02T13:45:00Z');
        (new FirmListImporter())->import('ftmo', [
            ['currency' => 'USD', 'title' => 'Non-Farm Payrolls', 'scheduledAtUtc' => '2026-10-02T12:30:00Z'],
        ], 'test');

        $user = User::create(['tz' => 'UTC', 'pro_until' => now()->addMonth()]);
        Setting::create(['user_id' => $user->id, 'mode' => 'firm-match', 'firm_id' => 'ftmo', 'account_type_id' => 'ftmo-account']);
        Instrument::create(['user_id' => $user->id, 'symbol' => 'XAUUSD', 'basket_currencies' => ['USD']]);

        $builder = app(EngineInputBuilder::class);
        $utc = new DateTimeZone('UTC');
        $input = $builder->build($user, new DateTimeImmutable('2026-10-02T00:00:00', $utc), new DateTimeImmutable('2026-10-03T00:00:00', $utc));
        $this->assertSame('ftmo', $input['packId']);
        $this->assertSame([(string) $nfp->id], $input['firmEventIds']);

        $conservative = User::create(['tz' => 'UTC']);
        Setting::create(['user_id' => $conservative->id]);
        $none = $builder->build($conservative, new DateTimeImmutable('2026-10-02T00:00:00', $utc), new DateTimeImmutable('2026-10-03T00:00:00', $utc));
        $this->assertArrayNotHasKey('firmEventIds', $none);
    }
}
