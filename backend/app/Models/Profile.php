<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Hub skeleton. Exists from day one so the hub never looks bolted on; dark at launch. */
class Profile extends Model
{
    protected $primaryKey = 'user_id';

    public $incrementing = false;

    protected $fillable = ['user_id', 'handle', 'avatar_url', 'visibility'];
}
