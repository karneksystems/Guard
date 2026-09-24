<?php

namespace App\Ladder\Jobs;

use App\Ladder\LadderReconciler;
use App\Models\User;
use Illuminate\Contracts\Queue\ShouldBeUniqueUntilProcessing;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Unique only while queued: a change that lands during a running reconcile
 * must queue another one, not vanish until the nightly sweep.
 */
final class ReconcileUserLadder implements ShouldQueue, ShouldBeUniqueUntilProcessing
{
    use Queueable;

    public int $tries = 3;

    /** @var list<int> */
    public array $backoff = [5, 30];

    public function __construct(public readonly int $userId)
    {
    }

    public function uniqueId(): string
    {
        return (string) $this->userId;
    }

    public function handle(LadderReconciler $reconciler): void
    {
        $user = User::query()->find($this->userId);
        if ($user === null) {
            return;
        }
        $counts = $reconciler->reconcile($user);
        if ($counts['created'] + $counts['cancelled'] > 0) {
            SendResyncNudge::dispatch($this->userId);
        }
    }
}
