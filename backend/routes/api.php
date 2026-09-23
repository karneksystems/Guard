<?php

use App\Http\Controllers\Api\DeviceController;
use App\Http\Controllers\Api\PackController;
use App\Http\Controllers\Api\SyncController;
use App\Http\Middleware\DeviceAuth;
use Illuminate\Support\Facades\Route;

Route::post('/devices', [DeviceController::class, 'register']);
Route::get('/packs', [PackController::class, 'index']);
Route::get('/packs/{firmId}', [PackController::class, 'show'])->where('firmId', '[a-z0-9-]{2,40}');

Route::middleware(DeviceAuth::class)->group(function () {
    Route::patch('/device', [DeviceController::class, 'update']);
    Route::get('/sync', [SyncController::class, 'show']);
    Route::put('/settings', [SyncController::class, 'updateSettings']);
    Route::put('/instruments', [SyncController::class, 'replaceInstruments']);
    Route::post('/journal', [SyncController::class, 'journal']);
});
