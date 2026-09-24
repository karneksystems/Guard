<?php

declare(strict_types=1);

namespace Karnek\RuleEngine\Tests;

use Karnek\RuleEngine\Engine;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class FixturesTest extends TestCase
{
    private const CASES = __DIR__ . '/../../../fixtures/rule-engine/cases';
    private const PACKS = __DIR__ . '/../../../packs';

    /** @return iterable<string, array{0: string}> */
    public static function cases(): iterable
    {
        foreach (glob(self::CASES . '/*.json') ?: [] as $path) {
            yield basename($path, '.json') => [$path];
        }
    }

    #[DataProvider('cases')]
    public function testCaseMatchesFixture(string $path): void
    {
        $case = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
        $engine = new Engine(static fn (string $firmId): array => json_decode(
            (string) file_get_contents(self::PACKS . '/' . $firmId . '.json'),
            true,
            512,
            JSON_THROW_ON_ERROR,
        ));

        if (isset($case['inputBefore'])) {
            $before = $engine->computeWindows($case['inputBefore']);
            $after = $engine->computeWindows($case['inputAfter']);
            $got = Engine::reconcile(
                $engine->computeLadder($case['inputBefore']['userId'], $before['windows']),
                $engine->computeLadder($case['inputAfter']['userId'], $after['windows']),
            );
            $got['windowsAfter'] = $after['windows'];
        } else {
            $result = $engine->computeWindows($case['input']);
            $got = [
                'windows' => $result['windows'],
                'ladder' => $engine->computeLadder($case['input']['userId'], $result['windows']),
                'notes' => $result['notes'],
            ];
        }

        self::assertSame(
            self::canonical($case['expected']),
            self::canonical($got),
            'Engine output drifted from ' . basename($path) . '. reference.py is the tie-breaker.',
        );
    }

    public function testEveryCaseHasAnExpectedBlock(): void
    {
        $count = 0;
        foreach (self::cases() as [$path]) {
            $case = json_decode((string) file_get_contents($path), true, 512, JSON_THROW_ON_ERROR);
            self::assertArrayHasKey('expected', $case, basename($path) . ' has no expected block; run reference.py --write');
            $count++;
        }
        self::assertSame(13, $count, 'expected thirteen fixture cases');
    }

    /** Sort associative keys recursively so key order never causes a false mismatch. */
    private static function canonical(mixed $value): mixed
    {
        if (!is_array($value)) {
            return $value;
        }
        $isList = array_is_list($value);
        $out = [];
        foreach ($value as $k => $v) {
            $out[$k] = self::canonical($v);
        }
        if (!$isList) {
            ksort($out);
        }

        return $out;
    }
}
