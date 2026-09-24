<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Ladder\EngineInputBuilder;
use App\Ladder\Jobs\ReconcileUserLadder;
use App\Models\CalendarEvent;
use App\Models\Instrument;
use App\Models\JournalEntry;
use App\Models\Rung;
use App\Models\User;
use App\Models\Window;
use DateInterval;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Everything the app pulls on a sync: settings, instruments, events for the horizon,
 * windows, the ladder for the local mirror, and the Pro flags. Plus the writes that
 * trigger a reconcile.
 */
final class SyncController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $now = EngineInputBuilder::utcNow();
        $eventsTo = $now->add(new DateInterval('P' . (int) config('guard.calendar_horizon_days') . 'D'));
        $ladderTo = $now->add(new DateInterval('PT' . (int) config('guard.ladder_horizon_hours') . 'H'));

        return response()->json([
            'serverTimeUtc' => $now->format('Y-m-d\TH:i:s\Z'),
            'calendarFetchedAt' => CalendarEvent::query()->max('fetched_at'),
            'pro' => $user->isPro(),
            'proUntil' => $user->pro_until?->utc()->format('Y-m-d\TH:i:s\Z'),
            'settings' => $user->settings,
            'instruments' => $user->instruments->map(fn (Instrument $i) => ['symbol' => $i->symbol, 'basket' => $i->basket_currencies])->values(),
            'events' => CalendarEvent::query()
                ->whereBetween('scheduled_at_utc', [$now->sub(new DateInterval('PT2H')), $eventsTo])
                ->orderBy('scheduled_at_utc')
                ->get()
                ->map(fn (CalendarEvent $e) => $e->toEngineEvent() + ['source' => $e->source, 'fetchedAt' => $e->fetched_at?->format('Y-m-d\TH:i:s\Z')])
                ->values(),
            'windows' => Window::query()->where('user_id', $user->id)->where('closes_at_utc', '>=', $now)->orderBy('opens_at_utc')->get()
                ->map(fn (Window $w) => ['windowId' => $w->id, 'instrument' => $w->instrument, 'opensAtUtc' => $w->opens_at_utc->format('Y-m-d\TH:i:s\Z'), 'closesAtUtc' => $w->closes_at_utc->format('Y-m-d\TH:i:s\Z'), 'reasons' => $w->reasons, 'verified' => $w->verified])
                ->values(),
            'ladder' => Rung::query()->where('user_id', $user->id)->where('state', Rung::SCHEDULED)->whereBetween('fire_at_utc', [$now, $ladderTo])->orderBy('fire_at_utc')->get()
                ->map(fn (Rung $r) => ['alertId' => $r->alert_id, 'windowId' => $r->window_id, 'kind' => $r->kind, 'fireAtUtc' => $r->fire_at_utc->format('Y-m-d\TH:i:s\Z')])
                ->values(),
        ]);
    }

    public function updateSettings(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = $request->validate([
            'mode' => ['sometimes', 'in:conservative,firm-match'],
            'protection' => ['sometimes', 'in:warn-only,soft-gate,hard-block'],
            'window_before_min' => ['sometimes', 'integer', 'min:0', 'max:1440'],
            'window_after_min' => ['sometimes', 'integer', 'min:0', 'max:1440'],
            'firm_id' => ['sometimes', 'nullable', 'regex:/^[a-z0-9-]{2,40}$/'],
            'account_type_id' => ['sometimes', 'nullable', 'regex:/^[a-z0-9-]{2,40}$/'],
            'quiet_hours' => ['sometimes', 'nullable', 'array:start,end'],
            'quiet_hours.start' => ['required_with:quiet_hours', 'date_format:H:i'],
            'quiet_hours.end' => ['required_with:quiet_hours', 'date_format:H:i'],
            'digest_local_time' => ['sometimes', 'date_format:H:i'],
        ]);

        if (!$user->isPro()) {
            // Free tier: fixed 5/5 window, conservative mode, no hard block (docs/FREE-PRO-FLAGS.md).
            unset($data['window_before_min'], $data['window_after_min']);
            if (($data['mode'] ?? null) === 'firm-match') {
                $data['mode'] = 'conservative';
            }
            if (($data['protection'] ?? null) === 'hard-block') {
                $data['protection'] = 'soft-gate';
            }
        }

        $user->settings()->updateOrCreate(['user_id' => $user->id], $data);
        ReconcileUserLadder::dispatch($user->id);

        return response()->json(['ok' => true, 'settings' => $user->settings()->first()]);
    }

    public function replaceInstruments(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = $request->validate([
            'instruments' => ['required', 'array', 'max:50'],
            'instruments.*.symbol' => ['required', 'string', 'max:16', 'regex:/^[A-Z0-9.]+$/'],
            'instruments.*.basket' => ['required', 'array', 'min:1', 'max:8'],
            'instruments.*.basket.*' => ['string', 'size:3', 'regex:/^[A-Z]{3}$/'],
        ]);

        $rows = $data['instruments'];
        if (!$user->isPro()) {
            $rows = array_slice($rows, 0, 2);
        }

        DB::transaction(function () use ($user, $rows) {
            Instrument::query()->where('user_id', $user->id)->delete();
            foreach ($rows as $row) {
                Instrument::create(['user_id' => $user->id, 'symbol' => $row['symbol'], 'basket_currencies' => array_values(array_unique($row['basket']))]);
            }
        });
        ReconcileUserLadder::dispatch($user->id);

        return response()->json(['ok' => true, 'count' => count($rows)]);
    }

    public function journal(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = $request->validate([
            'window_id' => ['required', 'string', 'size:20'],
            'outcome' => ['required', 'in:' . implode(',', JournalEntry::OUTCOMES)],
            'at_utc' => ['required', 'date'],
        ]);
        $entry = JournalEntry::create($data + ['user_id' => $user->id, 'device_id' => $request->attributes->get('device')->id]);

        return response()->json(['ok' => true, 'id' => $entry->id], 201);
    }
}
