<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A journal row outlives its window (windows prune after a week), so it
        // carries what it needs to render.
        Schema::table('journal_entries', function (Blueprint $table) {
            $table->string('instrument', 16)->nullable()->after('window_id');
            $table->timestamp('opens_at_utc')->nullable()->after('instrument');
            $table->timestamp('closes_at_utc')->nullable()->after('opens_at_utc');
        });
        // Events that vanish from the feed are kept but no longer open windows.
        Schema::table('calendar_events', function (Blueprint $table) {
            $table->timestamp('removed_at')->nullable()->after('fetched_at');
        });
        // One receipt, one account. A replay from another user is refused.
        Schema::create('receipts', function (Blueprint $table) {
            $table->id();
            $table->string('platform', 16);
            $table->string('original_transaction_id', 191);
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('plan', 16);
            $table->timestamp('expires_at');
            $table->timestamps();
            $table->unique(['platform', 'original_transaction_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('receipts');
        Schema::table('calendar_events', fn (Blueprint $t) => $t->dropColumn('removed_at'));
        Schema::table('journal_entries', fn (Blueprint $t) => $t->dropColumn(['instrument', 'opens_at_utc', 'closes_at_utc']));
    }
};
