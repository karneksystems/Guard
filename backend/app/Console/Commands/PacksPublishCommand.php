<?php

namespace App\Console\Commands;

use App\Packs\PackPublisher;
use Illuminate\Console\Command;

final class PacksPublishCommand extends Command
{
    protected $signature = 'packs:publish';

    protected $description = 'Publish firm packs and the version index to public storage';

    public function handle(PackPublisher $publisher): int
    {
        foreach ($publisher->publish() as $row) {
            $this->line(sprintf('%-16s %-22s %s', $row['firmId'], $row['packVersion'], $row['needsReverify'] ? 'unverified' : 'verified'));
        }

        return self::SUCCESS;
    }
}
