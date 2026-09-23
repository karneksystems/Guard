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
        [$before, $after, $selector, $affected, $verified, $notes] = $this->effectiveRule($input);
        if ($before === null) {
            return ['windows' => [], 'notes' => $notes];
        }

        if ($selector === 'firm-list') {
            $ids = array_flip($input['firmEventIds']);
            $events = array_values(array_filter(
                $input['events'],
                static fn (array $e): bool => isset($ids[$e['id']]) && empty($e['tentative']),
            ));
        } else {
            $events = array_values(array_filter(
                $input['events'],
                static fn (array $e): bool => $e['impact'] === 'high' && empty($e['tentative']),
            ));
        }

        $raw = [];
        foreach ($input['instruments'] as $instrument) {
            $basket = self::basketFor($instrument);
            foreach ($events as $event) {
                if ($affected === 'event-currency' && !in_array($event['currency'], $basket, true)) {
                    continue;
                }
                if ($affected === 'list' && !in_array($instrument['symbol'], $input['affectedList'] ?? [], true)) {
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

        usort($raw, static fn (array $a, array $b): int => [$a[0], $a[1], $a[2]] <=> [$b[0], $b[1], $b[2]]);

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
        usort($ladder, static fn (array $a, array $b): int =>
            [$a['fireAtUtc'], $a['windowId'], $a['kind']] <=> [$b['fireAtUtc'], $b['windowId'], $b['kind']]);

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
        sort($cancelled);
        sort($created);
        sort($kept);

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

    /** @return array{0: ?int, 1: ?int, 2: ?string, 3: ?string, 4: bool, 5: list<string>} */
    private function effectiveRule(array $input): array
    {
        $s = $input['settings'];
        $notes = [];
        if ($s['mode'] === 'conservative') {
            return [$s['windowBeforeMin'], $s['windowAfterMin'], 'high', 'event-currency', true, $notes];
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
        $verified = !$pack['needsReverify'];
        if (!$rule['applies']) {
            return [null, null, null, null, $verified, ['firm does not restrict news on this account type']];
        }

        $before = $rule['windowBeforeMin'];
        $after = $rule['windowAfterMin'];
        if (!$verified) {
            $before = max($before, $s['windowBeforeMin']);
            $after = max($after, $s['windowAfterMin']);
            $notes[] = 'pack unverified: using the larger of pack window and user default';
        }

        $selector = 'high';
        if ($rule['eventSet'] === 'firm-list') {
            if (!empty($input['firmEventIds'])) {
                $selector = 'firm-list';
            } else {
                $notes[] = "using the calendar, not the firm's list";
            }
        }

        return [$before, $after, $selector, $rule['affectedInstruments'], $verified, $notes];
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
