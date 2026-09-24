import 'package:flutter/material.dart';

import '../features/flags.dart';
import '../platform/platform_bridge.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import 'pack_screen.dart';
import 'paywall_screen.dart';
import 'permissions_screen.dart';
import 'tracker_screen.dart';

/// Everything from onboarding, editable afterwards. Writes go through the
/// controller, which applies locally and pushes to the backend.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final text = Theme.of(context).textTheme;
    final s = state.settings;
    final pro = state.pro;

    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Settings', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        _Row(
          key: const Key('setting-protection'),
          label: 'Protection',
          value: _label(s['protection'] as String? ?? 'soft-gate'),
          onTap: () => _pick(context, 'Protection', s['protection'] as String? ?? 'soft-gate', [
            ('warn-only', 'Warn only'),
            ('soft-gate', 'Soft gate'),
            ('hard-block', pro ? 'Hard block' : 'Hard block (Pro)'),
          ], disabled: pro ? const {} : const {'hard-block'}, onPicked: (v) => c.updateSettings({'protection': v})),
        ),
        _Row(
          key: const Key('setting-mode'),
          label: 'Rule mode',
          value: s['mode'] == 'firm-match' ? 'Firm match' : 'Conservative',
          onTap: () => _pick(context, 'Rule mode', s['mode'] as String? ?? 'conservative', [
            ('conservative', 'Conservative'),
            ('firm-match', pro ? 'Firm match' : 'Firm match (Pro)'),
          ], disabled: pro ? const {} : const {'firm-match'}, onPicked: (v) async {
            if (v == 'firm-match') {
              await _pickFirm(context, state, c);
            } else {
              await c.updateSettings({'mode': v});
            }
          }),
        ),
        if (s['mode'] == 'firm-match' && s['firmId'] != null)
          _Row(
            key: const Key('setting-firm'),
            label: 'Firm',
            value: _firmLabel(state),
            note: state.packs.index[s['firmId']]?.needsReverify == false ? null : 'unverified pack',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackScreen(firmId: s['firmId'] as String))),
          ),
        _Row(
          key: const Key('setting-window'),
          label: 'Window',
          value: '${s['windowBeforeMin']} min before · ${s['windowAfterMin']} min after',
          onTap: pro
              ? () => _pick(context, 'Window', '${s['windowBeforeMin']}', [
                    for (final m in Flags.windowPresets) ('$m', '$m minutes'),
                  ], onPicked: (v) => c.updateSettings({'windowBeforeMin': int.parse(v), 'windowAfterMin': int.parse(v)}))
              : null,
          note: pro ? null : 'Fixed on Free',
        ),
        _Row(
          key: const Key('setting-instruments'),
          label: 'Instruments',
          value: state.instruments.map((i) => i['symbol']).join(', '),
          onTap: () => _editInstruments(context, state, c),
        ),
        _Row(
          key: const Key('setting-gated'),
          label: 'Gated apps',
          value: c.bridge.usesSystemPicker ? 'Chosen in Screen Time' : '${state.gatedAppIds.length} selected',
          onTap: () => _editGatedApps(context, state, c),
        ),
        _Row(
          key: const Key('setting-digest'),
          label: 'Night-before digest',
          value: s['digestLocalTime'] as String? ?? '20:00',
          onTap: () async {
            final now = TimeOfDay(
              hour: int.parse((s['digestLocalTime'] as String? ?? '20:00').split(':').first),
              minute: int.parse((s['digestLocalTime'] as String? ?? '20:00').split(':').last),
            );
            final picked = await showTimePicker(context: context, initialTime: now);
            if (picked != null) {
              await c.updateSettings({
                'digestLocalTime': '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
              });
            }
          },
        ),
        _Row(
          key: const Key('setting-quiet'),
          label: 'Quiet hours',
          value: s['quietHours'] == null ? 'Off' : '${(s['quietHours'] as Map)['start']} to ${(s['quietHours'] as Map)['end']}',
          note: 'Only the 5 minute, 1 minute and open alerts fire inside them.',
          onTap: () => _editQuietHours(context, s, c),
        ),
        _Row(
          key: const Key('setting-tracker'),
          label: 'Tracker and reminders',
          value: state.tracker.dailyLossLimit == null ? 'Not set' : 'Limit ${state.tracker.currency}${state.tracker.dailyLossLimit!.toStringAsFixed(0)}',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrackerScreen())),
        ),
        if (c.bridge.supportedPermissions.length > 1)
          _Row(
            key: const Key('setting-permissions'),
            label: 'Permissions',
            value: state.missingPermissions.isEmpty ? 'All granted' : '${state.missingPermissions.length} missing',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
          ),
        _Row(
          key: const Key('setting-plan'),
          label: 'Plan',
          value: pro ? 'Pro' : 'Free',
          note: pro ? null : 'Pro unlocks firm packs, custom windows and hard block.',
          onTap: pro ? null : () => Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => const PaywallScreen())),
        ),
        const SizedBox(height: Tokens.gutter),
        Text('Not affiliated with any firm. Not financial advice.', style: text.bodySmall),
        const SizedBox(height: Tokens.gutter),
        TextButton(
          key: const Key('setting-delete'),
          onPressed: () => _deleteEverything(context, c),
          child: const Text('Delete my data'),
        ),
      ],
    );
  }

  Future<void> _editQuietHours(BuildContext context, Map<String, dynamic> s, GuardController c) async {
    final current = s['quietHours'] as Map?;
    TimeOfDay parse(String? v, TimeOfDay fallback) {
      if (v == null) return fallback;
      final p = v.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const Key('quiet-set'), title: const Text('Set quiet hours'), onTap: () => Navigator.of(ctx).pop('set')),
          ListTile(key: const Key('quiet-off'), title: const Text('Off'), onTap: () => Navigator.of(ctx).pop('off')),
        ]),
      ),
    );
    if (choice == 'off') {
      await c.updateSettings({'quietHours': null});
      return;
    }
    if (choice != 'set' || !context.mounted) return;
    final start = await showTimePicker(context: context, initialTime: parse(current?['start'] as String?, const TimeOfDay(hour: 23, minute: 0)), helpText: 'Quiet from');
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(context: context, initialTime: parse(current?['end'] as String?, const TimeOfDay(hour: 6, minute: 0)), helpText: 'Quiet until');
    if (end == null) return;
    await c.updateSettings({'quietHours': {'start': fmt(start), 'end': fmt(end)}});
  }

  Future<void> _deleteEverything(BuildContext context, GuardController c) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete my data?'),
        content: const Text('Removes your settings, instruments, journal and device from the server and wipes this app. Pro stays with your store account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(key: const Key('delete-confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    final ok = await c.deleteEverything();
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server. Nothing was deleted.')));
    }
  }

  static String _firmLabel(GuardState state) {
    final firmId = state.settings['firmId'] as String;
    final entry = state.packs.index[firmId];
    final account = entry?.accountTypes.where((a) => a.id == state.settings['accountTypeId']).firstOrNull;
    return '${entry?.firmName ?? firmId}${account == null ? '' : ' · ${account.label}'}';
  }

  /// Firm, then account type, from the cached index. Both are needed before
  /// the engine will run Firm match; until then it stays conservative.
  Future<void> _pickFirm(BuildContext context, GuardState state, GuardController c) async {
    final firms = state.packs.index.values.toList()..sort((a, b) => a.firmName.compareTo(b.firmName));
    if (firms.isEmpty) {
      await c.refreshPacks();
      if (!context.mounted) return;
      if (state.packs.index.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Packs arrive with the next sync. Try again shortly.')));
        return;
      }
      return _pickFirm(context, state, c);
    }
    final firmId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(Tokens.gutter), child: Text('Firm', style: Theme.of(ctx).textTheme.titleMedium)),
          for (final f in firms)
            ListTile(
              key: Key('firm-${f.firmId}'),
              title: Text(f.firmName),
              subtitle: Text(f.needsReverify ? 'Unverified pack ${f.packVersion}' : 'Verified ${f.lastVerified}'),
              onTap: () => Navigator.of(ctx).pop(f.firmId),
            ),
        ]),
      ),
    );
    if (firmId == null || !context.mounted) return;
    final firm = state.packs.index[firmId]!;
    final accountId = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(Tokens.gutter), child: Text('Account type', style: Theme.of(ctx).textTheme.titleMedium)),
          for (final a in firm.accountTypes)
            ListTile(
              key: Key('account-${a.id}'),
              title: Text(a.label),
              subtitle: Text(a.phase),
              onTap: () => Navigator.of(ctx).pop(a.id),
            ),
        ]),
      ),
    );
    if (accountId == null) return;
    await c.selectFirm(firmId: firmId, accountTypeId: accountId);
  }

  static String _label(String id) => switch (id) {
        'warn-only' => 'Warn only',
        'hard-block' => 'Hard block',
        _ => 'Soft gate',
      };

  Future<void> _pick(
    BuildContext context,
    String title,
    String current,
    List<(String, String)> options, {
    Set<String> disabled = const {},
    required ValueChanged<String> onPicked,
  }) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: current,
          onChanged: (x) => Navigator.of(ctx).pop(x),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(Tokens.gutter), child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
            for (final (id, label) in options)
              RadioListTile<String>(
                key: Key('option-$id'),
                value: id,
                enabled: !disabled.contains(id),
                title: Text(label),
              ),
          ]),
        ),
      ),
    );
    if (v != null && v != current) onPicked(v);
  }

  Future<void> _editInstruments(BuildContext context, GuardState state, GuardController c) async {
    final chosen = state.instruments.map((i) => i['symbol'] as String).toSet();
    const common = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'US30', 'US500', 'USTEC', 'DE40', 'UK100', 'BTCUSD'];
    final max = state.flags.instrumentsMax;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.gutter),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Instruments', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in common)
                  FilterChip(
                    key: Key('inst-$s'),
                    label: Text(s),
                    selected: chosen.contains(s),
                    onSelected: (on) => setSheet(() {
                      if (on && chosen.length < max) chosen.add(s);
                      if (!on) chosen.remove(s);
                    }),
                  ),
              ]),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const Key('inst-done'), onPressed: () => Navigator.of(ctx).pop(chosen), child: const Text('Done')),
              ),
            ]),
          ),
        );
      }),
    );
    if (result != null) {
      await c.replaceInstruments(result.map((s) => {'symbol': s}).toList());
    }
  }

  Future<void> _editGatedApps(BuildContext context, GuardState state, GuardController c) async {
    if (c.bridge.usesSystemPicker) {
      final ok = await c.bridge.pickApps();
      if (ok) await c.setGatedApps(const ['screen-time']);
      return;
    }
    final apps = await c.bridge.listApps();
    if (!context.mounted) return;
    final gated = state.gatedAppIds.toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(Tokens.gutter), child: Text('Gated apps', style: Theme.of(ctx).textTheme.titleMedium)),
            for (final app in apps)
              CheckboxListTile(
                key: Key('gate-${app.id}'),
                value: gated.contains(app.id),
                onChanged: (v) => setSheet(() => v == true ? gated.add(app.id) : gated.remove(app.id)),
                title: Text(app.label),
                subtitle: Text(app.installed ? 'Installed' : 'Not installed'),
              ),
            Padding(
              padding: const EdgeInsets.all(Tokens.gutter),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(key: const Key('gate-done'), onPressed: () => Navigator.of(ctx).pop(gated), child: const Text('Done')),
              ),
            ),
          ]),
        );
      }),
    );
    if (result != null) await c.setGatedApps(result.toList());
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.label, required this.value, this.onTap, this.note});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: note == null ? null : Text(note!, style: text.bodySmall),
      trailing: Text(value, style: text.bodySmall),
      onTap: onTap,
      enabled: onTap != null,
      shape: const Border(bottom: BorderSide(color: Tokens.champagneHairline)),
    );
  }
}

/// Exposed for tests that want the enum's label without the screen.
String permissionLabel(GuardPermission p) => p.label;
