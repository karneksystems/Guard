<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A firm's own restricted-event list, matched to our calendar rows. The engine
 * takes the matched ids as firmEventIds when the pack says eventSet firm-list.
 * Unmatched rows are kept so a human can see what the firm lists that our
 * vendor doesn't carry.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('firm_list_events', function (Blueprint $table) {
            $table->id();
            $table->string('firm_id', 40);
            $table->string('currency', 8);
            $table->string('title');
            $table->timestamp('scheduled_at_utc');
            $table->foreignId('calendar_event_id')->nullable()->constrained('calendar_events')->nullOnDelete();
            $table->string('source', 255);
            $table->timestamp('fetched_at');
            $table->timestamps();
            $table->index(['firm_id', 'scheduled_at_utc']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('firm_list_events');
    }
};
