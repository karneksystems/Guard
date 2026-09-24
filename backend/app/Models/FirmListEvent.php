<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FirmListEvent extends Model
{
    protected $fillable = ['firm_id', 'currency', 'title', 'scheduled_at_utc', 'calendar_event_id', 'source', 'fetched_at'];

    protected function casts(): array
    {
        return ['scheduled_at_utc' => 'immutable_datetime', 'fetched_at' => 'immutable_datetime'];
    }

    public function calendarEvent(): BelongsTo
    {
        return $this->belongsTo(CalendarEvent::class);
    }
}
