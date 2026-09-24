<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\EntitlementController;
use App\Http\Controllers\Api\PackController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Middleware\DeviceAuth;
use Illuminate\Support\Facades\Route;

// Anonymous registration creates rows; keep it to a handful per address per minute.
Route::post('/devices', [DeviceController::class, 'register'])->middleware('throttle:5,1');
Route::get('/packs', [PackController::class, 'index']);
Route::get('/packs/{firmId}', [PackController::class, 'show'])->where('firmId', '[a-z0-9-]{2,40}');

Route::middleware(DeviceAuth::class)->group(function () {
    Route::patch('/device', [DeviceController::class, 'update']);
    Route::get('/sync', [SyncController::class, 'show']);
    Route::put('/settings', [SyncController::class, 'updateSettings']);
    Route::put('/instruments', [SyncController::class, 'replaceInstruments']);
    Route::post('/journal', [SyncController::class, 'journal'])->middleware('throttle:60,1');
    Route::post('/entitlement', [EntitlementController::class, 'store'])->middleware('throttle:10,1');
    Route::delete('/account', [AccountController::class, 'destroy']);
});
