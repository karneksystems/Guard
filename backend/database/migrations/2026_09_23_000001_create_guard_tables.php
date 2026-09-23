<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Core tables from docs/ARCHITECTURE.md. Everything time-related is UTC.
 * Gated app identifiers never appear here; they live on the device only.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('platform', 16);                 // android, ios, windows, macos
            $table->string('api_token_hash', 64)->unique();
            $table->text('push_token')->nullable();
            $table->boolean('token_valid')->default(true);
            $table->string('tz', 64)->default('UTC');
            $table->string('app_version', 32)->nullable();
            $table->string('notif_state', 16)->default('unknown'); // unknown, granted, denied, invalid
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();
        });

        Schema::create('settings', function (Blueprint $table) {
            $table->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();
            $table->string('mode', 16)->default('conservative');   // conservative, firm-match
            $table->string('protection', 16)->default('soft-gate'); // warn-only, soft-gate, hard-block
            $table->unsignedSmallInteger('window_before_min')->default(5);
            $table->unsignedSmallInteger('window_after_min')->default(5);
            $table->string('firm_id', 40)->nullable();
            $table->string('account_type_id', 40)->nullable();
            $table->json('quiet_hours')->nullable();               // {"start":"23:00","end":"06:00"} local
            $table->string('digest_local_time', 5)->default('20:00');
            $table->timestamps();
        });

        Schema::create('instruments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('symbol', 16);
            $table->json('basket_currencies');
            $table->timestamps();
            $table->unique(['user_id', 'symbol']);
        });

        Schema::create('calendar_events', function (Blueprint $table) {
            $table->id();
            $table->string('vendor', 32);
            $table->string('vendor_id', 128);
            $table->string('currency', 8);
            $table->string('title');
            $table->string('impact', 8);                            // high, medium, low
            $table->timestamp('scheduled_at_utc');
            $table->timestamp('revised_from_utc')->nullable();
            $table->boolean('tentative')->default(false);
            $table->string('source', 128);
            $table->timestamp('fetched_at')->nullable();
            $table->timestamps();
            $table->unique(['vendor', 'vendor_id']);
            $table->index(['scheduled_at_utc', 'impact']);
        });

        Schema::create('windows', function (Blueprint $table) {
            $table->string('id', 20)->primary();                    // windowId from the engine
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('instrument', 16);
            $table->timestamp('opens_at_utc');
            $table->timestamp('closes_at_utc');
            $table->json('reasons');                                // event ids
            $table->boolean('verified')->default(true);
            $table->timestamps();
            $table->index(['user_id', 'opens_at_utc']);
        });

        Schema::create('rungs', function (Blueprint $table) {
            $table->string('alert_id', 20)->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('window_id', 20)->index();
            $table->string('kind', 8);                              // t-60, t-15, t-5, t-1, open, end
            $table->timestamp('fire_at_utc');
            $table->string('state', 12)->default('scheduled');      // scheduled, sent, cancelled, failed
            $table->string('provider_msg_id', 128)->nullable();
            $table->timestamps();
            $table->index(['user_id', 'fire_at_utc']);
        });

        Schema::create('journal_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('window_id', 20);
            $table->uuid('device_id')->nullable();
            $table->string('outcome', 16);                          // stayed-out, viewed, traded-anyway
            $table->timestamp('at_utc');
            $table->timestamps();
            $table->index(['user_id', 'at_utc']);
        });

        Schema::create('profiles', function (Blueprint $table) {
            $table->foreignId('user_id')->primary()->constrained()->cascadeOnDelete();
            $table->string('handle', 32)->nullable()->unique();
            $table->string('avatar_url')->nullable();
            $table->string('visibility', 8)->default('private');    // hub skeleton, dark at launch
            $table->timestamps();
        });

        Schema::create('firm_pack_versions', function (Blueprint $table) {
            $table->string('firm_id', 40);
            $table->string('pack_version', 32);
            $table->string('url');
            $table->string('sha256', 64);
            $table->boolean('needs_reverify');
            $table->timestamp('published_at');
            $table->primary(['firm_id', 'pack_version']);
        });
    }

    public function down(): void
    {
        foreach (['firm_pack_versions', 'profiles', 'journal_entries', 'rungs', 'windows',
            'calendar_events', 'instruments', 'settings', 'devices'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
