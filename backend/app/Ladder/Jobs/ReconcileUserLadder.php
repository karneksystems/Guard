<?php

namespace App\Ladder\Jobs;

use App\Ladder\LadderReconciler;
use App\Models\User;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

final class ReconcileUserLadder implements ShouldQueue, ShouldBeUnique
{
    use Queueable;

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
