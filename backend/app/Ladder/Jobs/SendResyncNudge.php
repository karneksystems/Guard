<?php

namespace App\Ladder\Jobs;

use App\Push\PushSender;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/** After a reconcile that changed rungs: tell the devices so their mirrors follow. */
final class SendResyncNudge implements ShouldQueue, ShouldBeUnique
{
    use Queueable;

    public int $tries = 1;

    public function __construct(public readonly int $userId)
    {
    }

    public function uniqueId(): string
    {
        return (string) $this->userId;
    }

    public function handle(PushSender $sender): void
    {
        $sender->sendResync($this->userId);
    }
}
