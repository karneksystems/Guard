<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Rung extends Model
{
    public const SCHEDULED = 'scheduled';

    public const SENT = 'sent';

    public const CANCELLED = 'cancelled';

    public const FAILED = 'failed';

    protected $primaryKey = 'alert_id';

    protected $keyType = 'string';

    public $incrementing = false;

    protected $fillable = ['alert_id', 'user_id', 'window_id', 'kind', 'fire_at_utc', 'state', 'provider_msg_id'];

    protected function casts(): array
    {
        return ['fire_at_utc' => 'immutable_datetime'];
    }
}
