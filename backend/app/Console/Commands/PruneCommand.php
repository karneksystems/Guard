<?php

namespace App\Console\Commands;

use App\Models\CalendarEvent;
use App\Models\FirmListEvent;
use App\Models\Rung;
use App\Models\Window;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Console\Command;

/**
 * Housekeeping. Rungs and windows are derived data with a short life; the
 * journal is the record and is never pruned here. Calendar rows go after
 * thirty days so an old reason id still resolves for a recent journal entry.
 */
final class PruneCommand extends Command
{
    protected $signature = 'guard:prune {--days=7 : Age of rungs and windows to drop} {--calendar-days=30 : Age of calendar and firm-list rows to drop}';

    protected $description = 'Delete sent or cancelled rungs, closed windows and old calendar rows';

    public function handle(): int
    {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $short = $now->sub(new DateInterval('P' . (int) $this->option('days') . 'D'));
        $long = $now->sub(new DateInterval('P' . (int) $this->option('calendar-days') . 'D'));

        $rungs = Rung::query()->whereIn('state', [Rung::SENT, Rung::CANCELLED, Rung::FAILED])->where('fire_at_utc', '<', $short)->delete();
        $windows = Window::query()->where('closes_at_utc', '<', $short)->delete();
        $events = CalendarEvent::query()->where('scheduled_at_utc', '<', $long)->delete();
        $firm = FirmListEvent::query()->where('scheduled_at_utc', '<', $long)->delete();

        $this->info(sprintf('pruned %d rungs, %d windows, %d calendar rows, %d firm-list rows', $rungs, $windows, $events, $firm));

        return self::SUCCESS;
    }
}
