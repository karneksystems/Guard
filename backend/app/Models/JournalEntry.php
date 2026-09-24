<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class JournalEntry extends Model
{
    public const OUTCOMES = ['stayed-out', 'viewed', 'traded-anyway'];

    protected $fillable = ['user_id', 'window_id', 'device_id', 'outcome', 'at_utc', 'instrument', 'opens_at_utc', 'closes_at_utc'];

    protected function casts(): array
    {
        return ['at_utc' => 'immutable_datetime', 'opens_at_utc' => 'immutable_datetime', 'closes_at_utc' => 'immutable_datetime'];
    }
}
