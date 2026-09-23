<?php

namespace App\Calendar;

use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Trading Economics calendar. Importance 3 is high, 2 medium, 1 low.
 * Endpoint shape from their public docs; confirm field names against a live key
 * during the vendor evaluation (docs/CALENDAR-VENDORS.md) before trusting it.
 */
final class TradingEconomicsAdapter implements VendorAdapter
{
    public function __construct(private readonly string $apiKey, private readonly string $baseUrl)
    {
        if ($this->apiKey === '') {
            throw new RuntimeException('TRADINGECONOMICS_API_KEY is not set');
        }
    }

    public function name(): string
    {
        return 'tradingeconomics';
    }

    public function fetch(DateTimeImmutable $from, DateTimeImmutable $to): array
    {
        $url = sprintf(
            '%s/calendar/country/all/%s/%s',
            rtrim($this->baseUrl, '/'),
            $from->format('Y-m-d'),
            $to->format('Y-m-d'),
        );
        $rows = Http::timeout(20)->retry(2, 500)->get($url, ['c' => $this->apiKey, 'f' => 'json'])->throw()->json();

        $out = [];
        foreach ($rows as $row) {
            if (empty($row['Date']) || empty($row['Currency'])) {
                continue;
            }
            $importance = (int) ($row['Importance'] ?? 0);
            $out[] = [
                'vendorId' => (string) ($row['CalendarId'] ?? md5($row['Event'] . $row['Date'] . $row['Country'])),
                'currency' => strtoupper($row['Currency']),
                'title' => (string) $row['Event'],
                'impact' => $importance >= 3 ? 'high' : ($importance === 2 ? 'medium' : 'low'),
                'scheduledAtUtc' => (new DateTimeImmutable($row['Date'], new DateTimeZone('UTC')))->setTimezone(new DateTimeZone('UTC')),
                'tentative' => false,
                'source' => 'Trading Economics',
            ];
        }

        return $out;
    }
}
