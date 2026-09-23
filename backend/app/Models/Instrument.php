<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Instrument extends Model
{
    protected $fillable = ['user_id', 'symbol', 'basket_currencies'];

    protected function casts(): array
    {
        return ['basket_currencies' => 'array'];
    }
}
