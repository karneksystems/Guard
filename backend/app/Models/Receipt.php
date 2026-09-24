<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Receipt extends Model
{
    protected $fillable = ['platform', 'original_transaction_id', 'user_id', 'plan', 'expires_at'];

    protected function casts(): array
    {
        return ['expires_at' => 'immutable_datetime'];
    }
}
