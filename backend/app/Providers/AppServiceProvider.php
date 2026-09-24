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
use App\Push\ApnsSender;
use App\Push\DeviceRouter;
use App\Push\FcmSender;
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
                'live' => new DeviceRouter(
                    self::apns(),
                    self::fcm(),
                    (int) config('guard.push_expiry_grace_seconds'),
                ),
                default => throw new RuntimeException('Unknown push sender ' . config('guard.push_sender')),
            };
        });

        $this->app->bind(LadderReconciler::class, fn ($app) => new LadderReconciler(
            $app->make(EngineInputBuilder::class),
            (int) config('guard.ladder_horizon_hours'),
        ));
    }

    private static function apns(): ?ApnsSender
    {
        $c = config('guard.apns');
        if (empty($c['team_id']) || empty($c['key_id']) || empty($c['private_key'])) {
            return null;
        }
        $pem = is_file($c['private_key']) ? (string) file_get_contents($c['private_key']) : (string) $c['private_key'];

        return new ApnsSender($c['team_id'], $c['key_id'], $pem, $c['bundle_id'], (bool) $c['sandbox']);
    }

    private static function fcm(): ?FcmSender
    {
        $path = config('guard.fcm.service_account');
        if (empty($path) || !is_file($path)) {
            return null;
        }

        return new FcmSender(json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR));
    }

    public function boot(): void
    {
        Event::listen(CalendarEventChanged::class, ReconcileLaddersForChangedEvent::class);
    }
}
