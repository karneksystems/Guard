<?php

namespace App\Console\Commands;

use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\User;
use Illuminate\Console\Command;

final class LadderReconcileCommand extends Command
{
    protected $signature = 'ladder:reconcile {user? : One user id, or every user with instruments when omitted}';

    protected $description = 'Queue a ladder reconcile for one user or for everyone (the nightly sweep)';

    public function handle(): int
    {
        $ids = $this->argument('user') !== null
            ? [(int) $this->argument('user')]
            : User::query()->whereHas('instruments')->pluck('id')->all();

        foreach ($ids as $id) {
            ReconcileUserLadder::dispatch((int) $id);
        }
        $this->info(sprintf('queued %d reconcile(s)', count($ids)));

        return self::SUCCESS;
    }
}
