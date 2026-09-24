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
        if (!is_array($rows)) {
            throw new RuntimeException('Trading Economics returned a non-JSON body');
        }

        $out = [];
        foreach ($rows as $row) {
            // Untrusted input: a malformed row is skipped, never allowed to abort the sync.
            if (!is_array($row) || empty($row['Date']) || empty($row['Currency']) || empty($row['Event']) || !is_string($row['Event'])) {
                continue;
            }
            try {
                $at = (new DateTimeImmutable((string) $row['Date'], new DateTimeZone('UTC')))->setTimezone(new DateTimeZone('UTC'));
            } catch (\Exception) {
                continue;
            }
            $currency = strtoupper(substr((string) $row['Currency'], 0, 8));
            if (!preg_match('/^[A-Z]{3}$/', $currency)) {
                continue;
            }
            $importance = (int) ($row['Importance'] ?? 0);
            $title = mb_substr(trim($row['Event']), 0, 255);
            $out[] = [
                // The fallback id must not include the date, or a moved event becomes a new one.
                'vendorId' => (string) ($row['CalendarId'] ?? md5($title . '|' . (string) ($row['Country'] ?? '') . '|' . $currency)),
                'currency' => $currency,
                'title' => $title,
                'impact' => $importance >= 3 ? 'high' : ($importance === 2 ? 'medium' : 'low'),
                'scheduledAtUtc' => $at,
                'tentative' => false,
                'source' => 'Trading Economics',
            ];
        }

        return $out;
    }
}
