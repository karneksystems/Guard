<?php

return [
    // Which calendar vendor adapter to bind: fake, tradingeconomics, fxmacrodata.
    'calendar_vendor' => env('GUARD_CALENDAR_VENDOR', 'fake'),

    // Path to a JSON file of events for the fake vendor (dev and tests).
    'fake_calendar_path' => env('GUARD_FAKE_CALENDAR', resource_path('fixtures/fake-calendar.json')),

    'tradingeconomics' => [
        'api_key' => env('TRADINGECONOMICS_API_KEY'),
        'base_url' => env('TRADINGECONOMICS_BASE_URL', 'https://api.tradingeconomics.com'),
    ],

    'fxmacrodata' => [
        'api_key' => env('FXMACRODATA_API_KEY'),
        'base_url' => env('FXMACRODATA_BASE_URL'),
    ],

    // How far ahead the calendar mirror and the ladder look.
    'calendar_horizon_days' => 14,
    'ladder_horizon_hours' => 48,

    // Where the firm packs live in the monorepo, relative to the backend.
    'packs_source_dir' => env('GUARD_PACKS_DIR', base_path('../packs')),

    // Which push sender to bind: log, apns, fcm (apns and fcm land in M3).
    'push_sender' => env('GUARD_PUSH_SENDER', 'log'),
];
