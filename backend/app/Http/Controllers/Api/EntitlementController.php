<?php

namespace App\Http\Controllers\Api;

use App\Billing\ReceiptVerifier;
use App\Http\Controllers\Controller;
use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\Receipt;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** A store receipt in, pro_until out. The server is the only place Pro is decided. */
final class EntitlementController extends Controller
{
    public function __construct(private readonly ReceiptVerifier $verifier)
    {
    }

    public function store(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $platforms = app()->environment('production') ? 'apple,google,microsoft' : 'apple,google,microsoft,fake';
        $data = $request->validate([
            'platform' => ['required', 'in:' . $platforms],
            'plan' => ['required', 'in:monthly,yearly'],
            'receipt' => ['required', 'string', 'max:8192'],
        ]);

        $verified = $this->verifier->verify($data['platform'], $data['plan'], $data['receipt']);
        if ($verified === null) {
            return response()->json(['ok' => false, 'proUntil' => null], 402);
        }

        // One purchase, one account: a receipt already bound elsewhere is refused.
        $receipt = Receipt::query()->firstOrNew(['platform' => $data['platform'], 'original_transaction_id' => $verified->originalTransactionId]);
        if ($receipt->exists && (int) $receipt->user_id !== (int) $user->id) {
            return response()->json(['ok' => false, 'proUntil' => null, 'error' => 'receipt belongs to another account'], 409);
        }
        $receipt->fill(['user_id' => $user->id, 'plan' => $data['plan'], 'expires_at' => $verified->expiresAt])->save();

        $until = $verified->expiresAt;
        // Never shorten an entitlement the user already holds.
        if ($user->pro_until === null || $user->pro_until->lessThan($until)) {
            $user->forceFill(['pro_until' => $until])->save();
            ReconcileUserLadder::dispatch($user->id);
        }

        return response()->json(['ok' => true, 'proUntil' => $user->pro_until->utc()->format('Y-m-d\TH:i:s\Z')]);
    }
}
