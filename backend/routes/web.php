<?php

use App\Models\CalendarEvent;
use Illuminate\Support\Facades\Route;

// The API lives under /api (routes/api.php). The root answers with a name so a
// load balancer or a curious browser gets something honest, and /up is Laravel's
// health check (bootstrap/app.php).
// calendarFetchedAt is what the uptime check watches: the vendor feed is stale
// at thirty minutes (PUSH-ARCHITECTURE, failure modes).
Route::get('/', fn () => response()->json([
    'service' => 'guard',
    'docs' => '/api',
    'timeUtc' => gmdate('Y-m-d\TH:i:s\Z'),
    'calendarFetchedAt' => CalendarEvent::query()->max('fetched_at'),
]));
