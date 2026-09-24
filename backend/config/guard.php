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

    // Which push sender to bind: log (development) or live (APNs plus FCM).
    'push_sender' => env('GUARD_PUSH_SENDER', 'log'),

    'apns' => [
        'team_id' => env('APNS_TEAM_ID'),
        'key_id' => env('APNS_KEY_ID'),
        // Either the .p8 contents, or a path to the file.
        'private_key' => env('APNS_PRIVATE_KEY'),
        'bundle_id' => env('APNS_BUNDLE_ID', 'com.stanchion.guard'),
        'sandbox' => (bool) env('APNS_SANDBOX', false),
    ],

    'fcm' => [
        // Path to the Firebase service-account JSON.
        'service_account' => env('FCM_SERVICE_ACCOUNT'),
    ],

    // Which receipt verifier to bind: reject (default, nothing gets Pro), fake
    // (dev and tests), or, once the store accounts exist, apple/google/microsoft.
    'receipt_verifier' => env('GUARD_RECEIPT_VERIFIER', 'reject'),

    // How long after fire_at a rung is still worth delivering. After this the
    // local mirror has fired and a late push would only repeat it.
    'push_expiry_grace_seconds' => 600,
];
