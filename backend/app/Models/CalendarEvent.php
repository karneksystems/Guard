<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CalendarEvent extends Model
{
    protected $fillable = ['vendor', 'vendor_id', 'currency', 'title', 'impact', 'scheduled_at_utc',
        'revised_from_utc', 'tentative', 'source', 'fetched_at'];

    protected function casts(): array
    {
        return [
            'scheduled_at_utc' => 'immutable_datetime',
            'revised_from_utc' => 'immutable_datetime',
            'fetched_at' => 'immutable_datetime',
            'tentative' => 'boolean',
        ];
    }

    /** The shape the rule engine consumes. */
    public function toEngineEvent(): array
    {
        return [
            'id' => (string) $this->id,
            'currency' => $this->currency,
            'title' => $this->title,
            'impact' => $this->impact,
            'scheduledAtUtc' => $this->scheduled_at_utc->utc()->format('Y-m-d\TH:i:s\Z'),
            'tentative' => $this->tentative,
        ];
    }
}
