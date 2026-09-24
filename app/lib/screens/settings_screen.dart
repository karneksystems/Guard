import 'package:flutter/material.dart';

import '../platform/platform_bridge.dart';
import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
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
          ], disabled: pro ? const {} : const {'firm-match'}, onPicked: (v) => c.updateSettings({'mode': v})),
        ),
        _Row(
          key: const Key('setting-window'),
          label: 'Window',
          value: '${s['windowBeforeMin']} min before · ${s['windowAfterMin']} min after',
          onTap: pro
              ? () => _pick(context, 'Window', '${s['windowBeforeMin']}', [
                    ('2', '2 minutes'),
                    ('3', '3 minutes'),
                    ('5', '5 minutes'),
                    ('10', '10 minutes'),
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
          value: '${state.gatedAppIds.length} selected',
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
        const SizedBox(height: Tokens.gutter),
        Text(pro ? 'Pro plan' : 'Free plan · Pro unlocks firm packs, custom windows and hard block.', style: text.bodySmall),
      ],
    );
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
    final max = state.pro ? 50 : 2;
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
