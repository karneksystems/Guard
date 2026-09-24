import 'package:flutter/material.dart';

import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';

/// One plain screen per the brief: each permission, why it's needed, and a button
/// that opens the OS page. Status refreshes when the user comes back.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final text = Theme.of(context).textTheme;
    final supported = c.bridge.supportedPermissions.toList()..sort((a, b) => a.index.compareTo(b.index));

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.gutter),
        children: [
          Text('Each one has a job. Without it, part of the guard can\'t work, and Home will say so.', style: text.bodyMedium),
          const SizedBox(height: Tokens.gutter),
          for (final p in supported)
            Card(
              child: ListTile(
                key: Key('perm-${p.name}'),
                title: Text(p.label),
                subtitle: Text(p.why),
                trailing: state.permissions[p] == true
                    ? const Icon(Icons.check, color: Tokens.metal)
                    : OutlinedButton(
                        key: Key('grant-${p.name}'),
                        onPressed: () => c.requestPermission(p),
                        child: const Text('Open settings'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown on Home while anything is missing. The honest version of "we can't
/// wake you" (docs/PUSH-ARCHITECTURE.md).
class PermissionBanner extends StatelessWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final missing = GuardScope.of(context).missingPermissions;
    if (missing.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('permission-banner'),
      color: Tokens.statusWarn.withValues(alpha: 0.12),
      child: ListTile(
        title: Text('${missing.length} permission${missing.length == 1 ? '' : 's'} missing', style: text.titleMedium),
        subtitle: Text(missing.map((p) => p.label).join(' · '), style: text.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
      ),
    );
  }
}
