<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Packs\PackRepository;
use Illuminate\Http\JsonResponse;
use RuntimeException;

final class PackController extends Controller
{
    public function __construct(private readonly PackRepository $packs)
    {
    }

    public function index(): JsonResponse
    {
        $rows = [];
        foreach ($this->packs->firmIds() as $firmId) {
            $pack = $this->packs->load($firmId);
            $rows[] = [
                'firmId' => $firmId,
                'firmName' => $pack['firmName'],
                'packVersion' => $pack['packVersion'],
                'needsReverify' => $pack['needsReverify'],
                'lastVerified' => $pack['lastVerified'],
                'accountTypes' => array_map(fn ($a) => ['id' => $a['id'], 'label' => $a['label'], 'phase' => $a['phase']], $pack['accountTypes']),
            ];
        }

        return response()->json(['packs' => $rows]);
    }

    public function show(string $firmId): JsonResponse
    {
        try {
            return response()->json($this->packs->load($firmId));
        } catch (RuntimeException) {
            return response()->json(['error' => 'not found'], 404);
        }
    }
}
