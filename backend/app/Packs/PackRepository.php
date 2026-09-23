<?php

namespace App\Packs;

use RuntimeException;

/** Reads firm packs from the monorepo's packs/ directory. Cached per request. */
final class PackRepository
{
    /** @var array<string, array> */
    private array $cache = [];

    public function __construct(private readonly string $dir)
    {
    }

    public function load(string $firmId): array
    {
        if (!preg_match('/^[a-z0-9-]{2,40}$/', $firmId)) {
            throw new RuntimeException('Bad firm id');
        }
        if (!isset($this->cache[$firmId])) {
            $path = rtrim($this->dir, '/') . '/' . $firmId . '.json';
            if (!is_file($path)) {
                throw new RuntimeException('No pack for ' . $firmId);
            }
            $this->cache[$firmId] = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        }

        return $this->cache[$firmId];
    }

    /** @return list<string> */
    public function firmIds(): array
    {
        $ids = [];
        foreach (glob(rtrim($this->dir, '/') . '/*.json') ?: [] as $path) {
            $ids[] = basename($path, '.json');
        }
        sort($ids);

        return $ids;
    }

    public function dir(): string
    {
        return $this->dir;
    }
}
