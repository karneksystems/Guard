<?php

namespace App\Http\Controllers\Api;

use App\Billing\ReceiptVerifier;
use App\Http\Controllers\Controller;
use App\Ladder\Jobs\ReconcileUserLadder;
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
        $data = $request->validate([
            'platform' => ['required', 'in:apple,google,microsoft,fake'],
            'plan' => ['required', 'in:monthly,yearly'],
            'receipt' => ['required', 'string', 'max:8192'],
        ]);

        $until = $this->verifier->verify($data['platform'], $data['plan'], $data['receipt']);
        if ($until === null) {
            return response()->json(['ok' => false, 'proUntil' => null], 402);
        }

        // Never shorten an entitlement the user already holds.
        if ($user->pro_until === null || $user->pro_until->lessThan($until)) {
            $user->forceFill(['pro_until' => $until])->save();
            ReconcileUserLadder::dispatch($user->id);
        }

        return response()->json(['ok' => true, 'proUntil' => $user->pro_until->utc()->format('Y-m-d\TH:i:s\Z')]);
    }
}
