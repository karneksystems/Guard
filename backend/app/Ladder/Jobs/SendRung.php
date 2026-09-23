<?php

namespace App\Ladder\Jobs;

use App\Models\Rung;
use App\Push\PushSender;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/**
 * Fires one rung. Idempotent: re-reads the row, skips anything not still scheduled,
 * marks sent with the provider's message id. Runs on the dedicated "ladder" queue.
 */
final class SendRung implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** @var list<int> seconds between retries; the mirror covers anything slower */
    public array $backoff = [5, 20, 60];

    public function __construct(public readonly string $alertId)
    {
    }

    public function handle(PushSender $sender): void
    {
        $rung = Rung::query()->find($this->alertId);
        if ($rung === null || $rung->state !== Rung::SCHEDULED) {
            return;
        }

        try {
            $providerId = $sender->sendRung($rung);
            $rung->forceFill(['state' => Rung::SENT, 'provider_msg_id' => $providerId])->save();
        } catch (Throwable $e) {
            if ($this->attempts() >= $this->tries) {
                $rung->forceFill(['state' => Rung::FAILED])->save();
            }
            throw $e;
        }
    }
}
