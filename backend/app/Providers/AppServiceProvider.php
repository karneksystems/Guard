<?php

namespace App\Providers;

use App\Calendar\FakeVendor;
use App\Calendar\TradingEconomicsAdapter;
use App\Calendar\VendorAdapter;
use App\Events\CalendarEventChanged;
use App\Ladder\EngineInputBuilder;
use App\Ladder\LadderReconciler;
use App\Listeners\ReconcileLaddersForChangedEvent;
use App\Packs\PackRepository;
use App\Push\LogPushSender;
use App\Push\PushSender;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(VendorAdapter::class, function () {
            return match (config('guard.calendar_vendor')) {
                'fake' => new FakeVendor(config('guard.fake_calendar_path')),
                'tradingeconomics' => new TradingEconomicsAdapter(
                    (string) config('guard.tradingeconomics.api_key'),
                    (string) config('guard.tradingeconomics.base_url'),
                ),
                default => throw new RuntimeException('Unknown calendar vendor ' . config('guard.calendar_vendor')),
            };
        });

        $this->app->singleton(PackRepository::class, fn () => new PackRepository((string) config('guard.packs_source_dir')));

        $this->app->singleton(PushSender::class, function () {
            return match (config('guard.push_sender')) {
                'log' => new LogPushSender(),
                default => throw new RuntimeException('Push sender ' . config('guard.push_sender') . ' lands in M3'),
            };
        });

        $this->app->bind(LadderReconciler::class, fn ($app) => new LadderReconciler(
            $app->make(EngineInputBuilder::class),
            (int) config('guard.ladder_horizon_hours'),
        ));
    }

    public function boot(): void
    {
        Event::listen(CalendarEventChanged::class, ReconcileLaddersForChangedEvent::class);
    }
}
