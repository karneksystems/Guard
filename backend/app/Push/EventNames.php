<?php

namespace App\Push;

/**
 * The names a trader uses, the same as app/lib/ui/words.dart: "Gold",
 * "EUR CPI", "BoE Rate". Keep the two in step.
 */
final class EventNames
{
    public static function market(string $symbol): string
    {
        return match (strtoupper($symbol)) {
            'XAUUSD' => 'Gold',
            'XAGUSD' => 'Silver',
            'EURUSD' => 'EUR',
            'GBPUSD' => 'GBP',
            'USDJPY' => 'JPY',
            'AUDUSD' => 'AUD',
            'USDCAD' => 'CAD',
            'USDCHF' => 'CHF',
            'US30', 'US500', 'USTEC', 'NAS100' => 'US indices',
            'DE40' => 'DAX',
            'UK100' => 'FTSE',
            'BTCUSD' => 'Bitcoin',
            'USOIL', 'WTI' => 'Oil',
            default => $symbol,
        };
    }

    public static function short(string $currency, string $title): string
    {
        $t = strtolower($title);
        $has = fn (string $s) => str_contains($t, $s);
        if ($has('non-farm') || $has('nonfarm')) {
            return 'NFP';
        }
        if ($has('fomc') || ($currency === 'USD' && $has('federal funds'))) {
            return 'FOMC';
        }
        foreach (['cpi' => 'CPI', 'pce' => 'PCE', 'gdp' => 'GDP', 'retail sales' => 'Retail Sales'] as $needle => $name) {
            if ($has($needle)) {
                return "$currency $name";
            }
        }
        if ($has('unemployment') || $has('employment change') || $has('jobless')) {
            return "$currency Jobs";
        }
        if ($has('pmi')) {
            return "$currency PMI";
        }
        if ($has('bank rate') || $has('rate decision') || $has('interest rate') || $has('cash rate') || $has('refinancing')) {
            $bank = match ($currency) {
                'GBP' => 'BoE', 'EUR' => 'ECB', 'USD' => 'Fed', 'JPY' => 'BoJ', 'AUD' => 'RBA',
                'CAD' => 'BoC', 'CHF' => 'SNB', 'NZD' => 'RBNZ', default => $currency,
            };

            return "$bank Rate";
        }

        return $title;
    }
}
