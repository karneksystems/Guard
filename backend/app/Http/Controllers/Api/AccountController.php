<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/** The privacy policy's deletion request, as one call. Every row cascades from the user. */
final class AccountController extends Controller
{
    public function destroy(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        DB::transaction(fn () => $user->delete());

        return response()->json(['ok' => true]);
    }
}
