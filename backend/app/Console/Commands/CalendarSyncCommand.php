<?php

namespace App\Console\Commands;

use App\Calendar\CalendarSync;
use App\Ladder\EngineInputBuilder;
use DateInterval;
use Illuminate\Console\Command;

final class CalendarSyncCommand extends Command
{
    protected $signature = 'calendar:sync {--hours= : Only sync this many hours ahead instead of the full horizon}';

    protected $description = 'Mirror the calendar vendor into calendar_events and report what moved';

    public function handle(CalendarSync $sync): int
    {
        $now = EngineInputBuilder::utcNow();
        $from = $now->sub(new DateInterval('PT2H'));
        $hours = $this->option('hours');
        $to = $hours !== null
            ? $now->add(new DateInterval('PT' . (int) $hours . 'H'))
            : $now->add(new DateInterval('P' . (int) config('guard.calendar_horizon_days') . 'D'));

        $counts = $sync->sync($from, $to);
        $this->info(sprintf('calendar: %d created, %d changed, %d unchanged', $counts['created'], $counts['changed'], $counts['unchanged']));

        return self::SUCCESS;
    }
}
