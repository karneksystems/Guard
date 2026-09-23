<?php

namespace App\Packs;

use App\Models\FirmPackVersion;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\Storage;

/**
 * Copies packs to public storage and records each version with its hash, so the
 * app can fetch the index daily and packs on demand. Schema validation happens in
 * CI (schema/validate_packs.py) before anything reaches this step.
 */
final class PackPublisher
{
    public function __construct(private readonly PackRepository $packs)
    {
    }

    /** @return list<array{firmId: string, packVersion: string, sha256: string, needsReverify: bool}> */
    public function publish(): array
    {
        $disk = Storage::disk('public');
        $index = [];
        $now = new DateTimeImmutable('now', new DateTimeZone('UTC'));

        foreach ($this->packs->firmIds() as $firmId) {
            $pack = $this->packs->load($firmId);
            $json = json_encode($pack, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
            $sha = hash('sha256', $json);
            $path = 'packs/' . $firmId . '.json';
            $disk->put($path, $json);

            FirmPackVersion::query()->updateOrCreate(
                ['firm_id' => $firmId, 'pack_version' => $pack['packVersion']],
                ['url' => $disk->url($path), 'sha256' => $sha, 'needs_reverify' => $pack['needsReverify'], 'published_at' => $now],
            );

            $index[] = [
                'firmId' => $firmId,
                'firmName' => $pack['firmName'],
                'packVersion' => $pack['packVersion'],
                'needsReverify' => $pack['needsReverify'],
                'sha256' => $sha,
                'url' => $disk->url($path),
            ];
        }

        $disk->put('packs/index.json', json_encode(['publishedAt' => $now->format('Y-m-d\TH:i:s\Z'), 'packs' => $index], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR));

        return $index;
    }
}
