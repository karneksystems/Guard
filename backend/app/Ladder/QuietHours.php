<?php

namespace App\Ladder;

use DateTimeImmutable;
use DateTimeZone;

/**
 * Optional quiet hours in the user's local time. Inside the range only T-5, T-1
 * and open fire; T-60, T-15 and end stay silent. A range that crosses midnight
 * (23:00 to 06:00) is the common case and works.
 */
final class QuietHours
{
    private const ALWAYS = ['t-5', 't-1', 'open'];

    private function __construct(
        private readonly int $startMin,
        private readonly int $endMin,
        private readonly DateTimeZone $tz,
    ) {
    }

    public static function fromSettings(?array $setting, string $tz): ?self
    {
        if ($setting === null || !isset($setting['start'], $setting['end'])) {
            return null;
        }
        try {
            $zone = new DateTimeZone($tz);
        } catch (\Exception) {
            $zone = new DateTimeZone('UTC');
        }

        return new self(self::minutes($setting['start']), self::minutes($setting['end']), $zone);
    }

    public function silences(string $kind, DateTimeImmutable $fireAtUtc): bool
    {
        if (in_array($kind, self::ALWAYS, true)) {
            return false;
        }

        return $this->contains($fireAtUtc);
    }

    public function contains(DateTimeImmutable $utc): bool
    {
        $local = $utc->setTimezone($this->tz);
        $m = (int) $local->format('G') * 60 + (int) $local->format('i');
        if ($this->startMin === $this->endMin) {
            return false;
        }
        if ($this->startMin < $this->endMin) {
            return $m >= $this->startMin && $m < $this->endMin;
        }

        return $m >= $this->startMin || $m < $this->endMin;
    }

    private static function minutes(string $hhmm): int
    {
        [$h, $i] = array_map('intval', explode(':', $hhmm) + [0, 0]);

        return $h * 60 + $i;
    }
}
