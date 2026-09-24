<?php

use Illuminate\Support\Facades\Route;

// The API lives under /api (routes/api.php). The root answers with a name so a
// load balancer or a curious browser gets something honest, and /up is Laravel's
// health check (bootstrap/app.php).
Route::get('/', fn () => response()->json(['service' => 'guard', 'docs' => '/api']));
