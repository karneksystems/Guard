<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    protected $primaryKey = 'user_id';

    public $incrementing = false;

    protected $fillable = ['user_id', 'mode', 'protection', 'window_before_min', 'window_after_min',
        'firm_id', 'account_type_id', 'quiet_hours', 'digest_local_time'];

    protected function casts(): array
    {
        return [
            'quiet_hours' => 'array',
            'window_before_min' => 'integer',
            'window_after_min' => 'integer',
        ];
    }
}
