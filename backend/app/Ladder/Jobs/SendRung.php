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
        // Claim the rung first: exactly one worker moves it from scheduled to
        // sending, so a duplicate dispatch or a retry after the provider already
        // accepted the push can never send it twice. A rung left in sending
        // after a crash is not resent: one alert lost beats two delivered.
        $claimed = Rung::query()
            ->where('alert_id', $this->alertId)
            ->where('state', Rung::SCHEDULED)
            ->update(['state' => Rung::SENDING]);
        if ($claimed !== 1) {
            return;
        }
        $rung = Rung::query()->find($this->alertId);
        if ($rung === null) {
            return;
        }

        try {
            $providerId = $sender->sendRung($rung);
        } catch (Throwable $e) {
            if ($this->attempts() >= $this->tries) {
                $rung->forceFill(['state' => Rung::FAILED])->save();
            } else {
                $rung->forceFill(['state' => Rung::SCHEDULED])->save(); // the retry claims it again
            }
            throw $e;
        }
        $rung->forceFill(['state' => Rung::SENT, 'provider_msg_id' => $providerId])->save();
    }
}
