<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Window extends Model
{
    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = ['id', 'user_id', 'instrument', 'opens_at_utc', 'closes_at_utc', 'reasons', 'verified'];

    protected function casts(): array
    {
        return [
            'opens_at_utc' => 'immutable_datetime',
            'closes_at_utc' => 'immutable_datetime',
            'reasons' => 'array',
            'verified' => 'boolean',
        ];
    }
}
