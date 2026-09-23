<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class Device extends Model
{
    use HasUuids;

    protected $fillable = ['user_id', 'platform', 'api_token_hash', 'push_token', 'token_valid',
        'tz', 'app_version', 'notif_state', 'last_seen_at'];

    protected function casts(): array
    {
        return ['token_valid' => 'boolean', 'last_seen_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Returns the plaintext token exactly once; only its hash is stored. */
    public static function issueToken(): array
    {
        $plain = Str::random(48);

        return [$plain, hash('sha256', $plain)];
    }

    public static function findByToken(?string $plain): ?self
    {
        if ($plain === null || $plain === '') {
            return null;
        }

        return static::query()->where('api_token_hash', hash('sha256', $plain))->first();
    }
}
