<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FirmPackVersion extends Model
{
    public $timestamps = false;

    public $incrementing = false;

    protected $primaryKey = null;

    protected $fillable = ['firm_id', 'pack_version', 'url', 'sha256', 'needs_reverify', 'published_at'];

    protected function casts(): array
    {
        return ['needs_reverify' => 'boolean', 'published_at' => 'immutable_datetime'];
    }
}
