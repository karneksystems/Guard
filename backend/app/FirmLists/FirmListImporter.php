<?php

namespace App\FirmLists;

use App\Models\CalendarEvent;
use App\Models\FirmListEvent;
use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use Illuminate\Support\Facades\DB;

/**
 * Takes a firm's list as normalised rows (currency, title, scheduledAtUtc) and
 * matches each to a calendar event: same currency, within five minutes, and a
 * title that shares its key words. The vendor's row wins on time; the firm's
 * list only says which events count. Replaces the firm's list wholesale for the
 * dates covered, so a re-import after the firm edits its page is safe.
 *
 * Fetching and parsing a firm's page is per firm and lands with each
 * eventListUrl; this class is the part that doesn't change.
 */
final class FirmListImporter
{
    private const MATCH_WINDOW = 'PT5M';

    /**
     * @param list<array{currency:string,title:string,scheduledAtUtc:string}> $rows
     * @return array{imported:int, matched:int, unmatched:list<string>}
     */
    public function import(string $firmId, array $rows, string $source, ?DateTimeImmutable $now = null): array
    {
        $now ??= new DateTimeImmutable('now', new DateTimeZone('UTC'));
        $utc = new DateTimeZone('UTC');
        $matched = 0;
        $unmatched = [];

        return DB::transaction(function () use ($firmId, $rows, $source, $now, $utc, &$matched, &$unmatched) {
            $dates = [];
            foreach ($rows as $r) {
                $dates[(new DateTimeImmutable($r['scheduledAtUtc'], $utc))->format('Y-m-d')] = true;
            }
            foreach (array_keys($dates) as $day) {
                FirmListEvent::query()
                    ->where('firm_id', $firmId)
                    ->whereBetween('scheduled_at_utc', [$day . ' 00:00:00', $day . ' 23:59:59'])
                    ->delete();
            }

            foreach ($rows as $r) {
                $at = new DateTimeImmutable($r['scheduledAtUtc'], $utc);
                $event = $this->match($r['currency'], $r['title'], $at);
                FirmListEvent::create([
                    'firm_id' => $firmId,
                    'currency' => strtoupper($r['currency']),
                    'title' => $r['title'],
                    'scheduled_at_utc' => $at,
                    'calendar_event_id' => $event?->id,
                    'source' => $source,
                    'fetched_at' => $now,
                ]);
                if ($event !== null) {
                    $matched++;
                } else {
                    $unmatched[] = sprintf('%s %s %s', $at->format('Y-m-d H:i'), strtoupper($r['currency']), $r['title']);
                }
            }

            return ['imported' => count($rows), 'matched' => $matched, 'unmatched' => $unmatched];
        });
    }

    private function match(string $currency, string $title, DateTimeImmutable $at): ?CalendarEvent
    {
        $window = new DateInterval(self::MATCH_WINDOW);
        $candidates = CalendarEvent::query()
            ->where('currency', strtoupper($currency))
            ->whereBetween('scheduled_at_utc', [$at->sub($window), $at->add($window)])
            ->get();
        if ($candidates->isEmpty()) {
            return null;
        }
        $want = self::keywords($title);
        $best = null;
        $bestScore = 0;
        foreach ($candidates as $c) {
            $have = self::keywords($c->title);
            $score = count(array_intersect($want, $have));
            if ($score > $bestScore) {
                $best = $c;
                $bestScore = $score;
            }
        }
        // One candidate at the same minute with nothing in common is still the firm's
        // event nine times out of ten (naming differs between vendors); take it.
        if ($best === null && $candidates->count() === 1) {
            return $candidates->first();
        }

        return $best;
    }

    /** @return list<string> */
    public static function keywords(string $title): array
    {
        $stop = ['the', 'of', 'and', 'a', 'in', 'to', 'for', 'on', 'y/y', 'm/m', 'q/q', 'flash', 'final', 'prelim', 'change', 'index', 'rate', 'report'];
        // Hyphens join, so Non-Farm and Nonfarm are the same word.
        $words = preg_split('/[^a-z0-9]+/', str_replace('-', '', strtolower($title))) ?: [];

        return array_values(array_filter($words, fn ($w) => strlen($w) > 1 && !in_array($w, $stop, true)));
    }
}
