<?php

namespace App\Console\Commands;

use App\Ladder\Jobs\SendRung;
use App\Models\Rung;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Console\Command;

/**
 * Every minute: any rung still scheduled but due in the last ten minutes gets
 * its job dispatched again. A lost queue job (picked up before commit, Redis
 * flushed, wrong queue connection) must not mean a silent miss. SendRung's
 * claim makes a duplicate job harmless.
 */
final class LadderSweepCommand extends Command
{
    protected $signature = 'ladder:sweep';

    protected $description = 'Re-dispatch overdue rungs whose job went missing';

    public function handle(): int
    {
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $ids = Rung::query()
            ->where('state', Rung::SCHEDULED)
            ->whereBetween('fire_at_utc', [$now->sub(new DateInterval('PT10M')), $now])
            ->pluck('alert_id');
        foreach ($ids as $id) {
            SendRung::dispatch($id)->onQueue('ladder');
        }
        $this->info(sprintf('re-dispatched %d overdue rungs', $ids->count()));

        return self::SUCCESS;
    }
}
