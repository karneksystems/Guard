<?php

namespace App\Console\Commands;

use App\FirmLists\FirmListImporter;
use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\Setting;
use Illuminate\Console\Command;

/**
 * Import a firm's restricted-event list from a JSON file of
 * [{"currency":"USD","title":"Non-Farm Payrolls","scheduledAtUtc":"2026-10-02T12:30:00Z"}, ...]
 * and reconcile every user on that firm. The per-firm fetcher that produces the
 * file from the firm's page lands with its eventListUrl.
 */
final class FirmListImportCommand extends Command
{
    protected $signature = 'firm-list:import {firmId} {path : JSON file of rows} {--source= : Where the rows came from, defaults to the path}';

    protected $description = "Import a firm's own restricted-event list and match it to the calendar";

    public function handle(FirmListImporter $importer): int
    {
        $firmId = (string) $this->argument('firmId');
        $path = (string) $this->argument('path');
        if (!preg_match('/^[a-z0-9-]{2,40}$/', $firmId) || !is_file($path)) {
            $this->error('Need a firm id and a readable file.');

            return self::FAILURE;
        }
        $rows = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        $result = $importer->import($firmId, $rows, (string) ($this->option('source') ?: $path));
        $this->info(sprintf('%s: %d rows, %d matched', $firmId, $result['imported'], $result['matched']));
        foreach ($result['unmatched'] as $line) {
            $this->warn('unmatched: ' . $line);
        }

        foreach (Setting::query()->where('firm_id', $firmId)->pluck('user_id') as $userId) {
            ReconcileUserLadder::dispatch($userId);
        }

        return self::SUCCESS;
    }
}
