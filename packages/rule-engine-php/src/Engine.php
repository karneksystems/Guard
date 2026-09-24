<?php

declare(strict_types=1);

namespace Karnek\RuleEngine;

use DateInterval;
use DateTimeImmutable;
use DateTimeZone;
use RuntimeException;

/**
 * The rule engine, as specified in docs/RULE-ENGINE.md.
 *
 * This is a pure function of its input. It reads no clock, no database and no
 * network. fixtures/rule-engine/reference.py is the tie-breaker when this and the
 * Dart engine disagree; both must pass every case in fixtures/rule-engine/cases.
 */
final class Engine
{
    /** @var array<string, list<string>> */
    public const DEFAULT_BASKETS = [
        'XAUUSD' => ['USD', 'EUR', 'GBP'], 'XAGUSD' => ['USD', 'EUR', 'GBP'],
        'US30' => ['USD'], 'US500' => ['USD'], 'USTEC' => ['USD'], 'US2000' => ['USD'],
        'DE40' => ['EUR'], 'FR40' => ['EUR'], 'EU50' => ['EUR'], 'UK100' => ['GBP'],
        'JP225' => ['JPY'], 'HK50' => ['CNY', 'HKD'], 'AUS200' => ['AUD'],
        'USOIL' => ['USD'], 'UKOIL' => ['USD'], 'BTCUSD' => ['USD'], 'ETHUSD' => ['USD'],
    ];

    /** @var list<array{0: string, 1: int}> */
    private const RUNGS = [['t-60', -60], ['t-15', -15], ['t-5', -5], ['t-1', -1], ['open', 0]];

    private const TS = 'Y-m-d\TH:i:s\Z';

    /**
     * @param callable(string): array $packLoader  Given a firm id, returns the decoded pack.
     */
    public function __construct(private $packLoader)
    {
    }

    /**
     * @param array $input  A case's "input" block: userId, settings, instruments, events, and
     *                      for firm match packId or pack, accountTypeId, optional firmEventIds.
     * @return array{windows: list<array>, notes: list<string>}
     */
    public function computeWindows(array $input): array
    {
        [$before, $after, $selector, $affected, $verified, $notes, $affectedList] = $this->effectiveRule($input);
        if ($before === null) {
            return ['windows' => [], 'notes' => $notes];
        }

        // Only a real boolean true is tentative; strings and numbers are not booleans.
        $live = array_values(array_filter($input['events'], static fn (array $e): bool => ($e['tentative'] ?? null) !== true));
        $events = [];
        if ($selector === 'firm-list') {
            $ids = array_flip(array_map('strval', $input['firmEventIds']));
            $events = array_values(array_filter($live, static fn (array $e): bool => isset($ids[(string) $e['id']])));
        }
        if ($selector !== 'firm-list' || $events === []) {
            // No list, or a list that names nothing we have: unknown means not
            // allowed, so the calendar's high-impact set applies.
            if ($selector === 'firm-list') {
                $notes[] = "using the calendar, not the firm's list";
            }
            $events = array_values(array_filter($live, static fn (array $e): bool => $e['impact'] === 'high'));
        }

        $raw = [];
        $seen = [];
        foreach ($input['instruments'] as $instrument) {
            if (isset($seen[$instrument['symbol']])) {
                continue; // a duplicate instrument must not duplicate reasons
            }
            $seen[$instrument['symbol']] = true;
            $basket = self::basketFor($instrument);
            foreach ($events as $event) {
                if ($affected === 'event-currency' && !in_array($event['currency'], $basket, true)) {
                    continue;
                }
                if ($affected === 'list' && !in_array($instrument['symbol'], $affectedList, true)) {
                    continue;
                }
                $t = self::parse($event['scheduledAtUtc']);
                $raw[] = [
                    $instrument['symbol'],
                    $t->sub(new DateInterval('PT' . $before . 'M')),
                    $t->add(new DateInterval('PT' . $after . 'M')),
                    $event['id'],
                ];
            }
        }

        // Event id last so the order is total and byte-wise, same as the Dart engine.
        usort($raw, static function (array $a, array $b): int {
            return strcmp($a[0], $b[0]) ?: ($a[1] <=> $b[1]) ?: ($a[2] <=> $b[2]) ?: strcmp((string) $a[3], (string) $b[3]);
        });

        $merged = [];
        foreach ($raw as [$symbol, $opens, $closes, $eventId]) {
            $last = count($merged) - 1;
            if ($last >= 0 && $merged[$last][0] === $symbol && $opens <= $merged[$last][2]) {
                if ($closes > $merged[$last][2]) {
                    $merged[$last][2] = $closes;
                }
                $merged[$last][3][] = $eventId;
            } else {
                $merged[] = [$symbol, $opens, $closes, [$eventId]];
            }
        }

        $windows = [];
        foreach ($merged as [$symbol, $opens, $closes, $reasons]) {
            $o = self::fmt($opens);
            $c = self::fmt($closes);
            $windows[] = [
                'windowId' => self::shortSha($input['userId'], $symbol, $o, $c),
                'instrument' => $symbol,
                'opensAtUtc' => $o,
                'closesAtUtc' => $c,
                'reasons' => $reasons,
                'verified' => $verified,
            ];
        }

        return ['windows' => $windows, 'notes' => $notes];
    }

    /**
     * @param list<array> $windows
     * @return list<array{alertId: string, windowId: string, kind: string, fireAtUtc: string}>
     */
    public function computeLadder(string $userId, array $windows): array
    {
        $ladder = [];
        foreach ($windows as $w) {
            $opens = self::parse($w['opensAtUtc']);
            foreach (self::RUNGS as [$kind, $delta]) {
                $fire = $delta === 0 ? $opens : $opens->sub(new DateInterval('PT' . (-$delta) . 'M'));
                $ladder[] = [
                    'alertId' => self::shortSha($userId, $w['windowId'], $kind, $w['opensAtUtc']),
                    'windowId' => $w['windowId'],
                    'kind' => $kind,
                    'fireAtUtc' => self::fmt($fire),
                ];
            }
            $ladder[] = [
                'alertId' => self::shortSha($userId, $w['windowId'], 'end', $w['opensAtUtc']),
                'windowId' => $w['windowId'],
                'kind' => 'end',
                'fireAtUtc' => $w['closesAtUtc'],
            ];
        }
        // strcmp, not <=>: a numeric-looking sha1 prefix must not compare as a number.
        usort($ladder, static fn (array $a, array $b): int =>
            strcmp($a['fireAtUtc'], $b['fireAtUtc']) ?: strcmp($a['windowId'], $b['windowId']) ?: strcmp($a['kind'], $b['kind']));

        return $ladder;
    }

    /**
     * Reconcile two ladders: what to cancel, what to create, what to leave alone.
     *
     * @return array{cancelledAlertIds: list<string>, createdAlertIds: list<string>, keptAlertIds: list<string>}
     */
    public static function reconcile(array $before, array $after): array
    {
        $b = array_column($before, 'alertId');
        $a = array_column($after, 'alertId');
        $cancelled = array_values(array_diff($b, $a));
        $created = array_values(array_diff($a, $b));
        $kept = array_values(array_intersect($b, $a));
        sort($cancelled, SORT_STRING);
        sort($created, SORT_STRING);
        sort($kept, SORT_STRING);

        return ['cancelledAlertIds' => $cancelled, 'createdAlertIds' => $created, 'keptAlertIds' => $kept];
    }

    /** @return list<string> */
    public static function basketFor(array $instrument): array
    {
        if (!empty($instrument['basket'])) {
            return $instrument['basket'];
        }
        $symbol = strtoupper($instrument['symbol']);
        if (isset(self::DEFAULT_BASKETS[$symbol])) {
            return self::DEFAULT_BASKETS[$symbol];
        }
        if (strlen($symbol) === 6 && ctype_alpha($symbol)) {
            return [substr($symbol, 0, 3), substr($symbol, 3)];
        }

        return ['USD'];
    }

    /**
     * Minutes are whole and never negative; anything else is a bad input, not a
     * window of some other size. Both engines reject the same things.
     */
    public static function minutes(mixed $v, string $field): int
    {
        if (is_int($v) && $v >= 0) {
            return $v;
        }
        if (is_float($v) && floor($v) === $v && $v >= 0) {
            return (int) $v;
        }
        if (is_string($v) && preg_match('/^\d+$/', $v)) {
            return (int) $v;
        }
        throw new RuntimeException("$field must be a whole number of minutes, got " . var_export($v, true));
    }

    /** @return array{0: ?int, 1: ?int, 2: ?string, 3: ?string, 4: bool, 5: list<string>, 6: list<string>} */
    private function effectiveRule(array $input): array
    {
        $s = $input['settings'];
        $notes = [];
        $userBefore = self::minutes($s['windowBeforeMin'] ?? null, 'windowBeforeMin');
        $userAfter = self::minutes($s['windowAfterMin'] ?? null, 'windowAfterMin');
        if ($s['mode'] === 'conservative') {
            return [$userBefore, $userAfter, 'high', 'event-currency', true, $notes, []];
        }

        $pack = $input['pack'] ?? ($this->packLoader)($input['packId']);
        $account = null;
        foreach ($pack['accountTypes'] as $candidate) {
            if ($candidate['id'] === $input['accountTypeId']) {
                $account = $candidate;
                break;
            }
        }
        if ($account === null) {
            throw new RuntimeException('Unknown account type ' . $input['accountTypeId']);
        }
        $rule = $account['newsRule'];
        // Unknown means not allowed (RULE-ENGINE.md): a missing field reads as its
        // most restrictive value. Only a real boolean counts as a boolean.
        $verified = ($pack['needsReverify'] ?? null) === false;
        if (($rule['applies'] ?? null) === false) {
            return [null, null, null, null, $verified, ['firm does not restrict news on this account type'], []];
        }

        $before = isset($rule['windowBeforeMin']) ? self::minutes($rule['windowBeforeMin'], 'windowBeforeMin') : $userBefore;
        $after = isset($rule['windowAfterMin']) ? self::minutes($rule['windowAfterMin'], 'windowAfterMin') : $userAfter;
        if (!$verified) {
            $before = max($before, $userBefore);
            $after = max($after, $userAfter);
            $notes[] = 'pack unverified: using the larger of pack window and user default';
        }

        $selector = 'high';
        if (($rule['eventSet'] ?? 'calendar-high-impact') === 'firm-list') {
            if (!empty($input['firmEventIds'])) {
                $selector = 'firm-list';
            } else {
                $notes[] = "using the calendar, not the firm's list";
            }
        }

        $affectedList = array_values(array_unique(array_map('strval', array_merge(
            $rule['instruments'] ?? [],
            $input['affectedList'] ?? [],
        ))));

        return [$before, $after, $selector, $rule['affectedInstruments'] ?? 'all', $verified, $notes, $affectedList];
    }

    private static function parse(string $ts): DateTimeImmutable
    {
        $dt = DateTimeImmutable::createFromFormat(self::TS, $ts, new DateTimeZone('UTC'));
        if ($dt === false) {
            throw new RuntimeException('Bad timestamp ' . $ts);
        }

        return $dt;
    }

    private static function fmt(DateTimeImmutable $dt): string
    {
        return $dt->setTimezone(new DateTimeZone('UTC'))->format(self::TS);
    }

    private static function shortSha(string ...$parts): string
    {
        return substr(sha1(implode('|', $parts)), 0, 20);
    }
}
