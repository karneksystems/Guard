<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;

/**
 * Accounts are anonymous and device-bound by default. Email is optional and only
 * used to link devices. There is no column for any trading credential, by design.
 */
class User extends Authenticatable
{
    use HasFactory;

    protected $fillable = ['name', 'email', 'tz', 'pro_until'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return ['pro_until' => 'datetime'];
    }

    public function isPro(): bool
    {
        return $this->pro_until !== null && $this->pro_until->isFuture();
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function settings(): HasOne
    {
        return $this->hasOne(Setting::class);
    }

    public function instruments(): HasMany
    {
        return $this->hasMany(Instrument::class);
    }

    public function windows(): HasMany
    {
        return $this->hasMany(Window::class);
    }

    public function rungs(): HasMany
    {
        return $this->hasMany(Rung::class);
    }

    public function journal(): HasMany
    {
        return $this->hasMany(JournalEntry::class);
    }

    public function profile(): HasOne
    {
        return $this->hasOne(Profile::class);
    }
}
