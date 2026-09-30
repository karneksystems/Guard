import 'package:flutter/material.dart';

import '../state/guard_controller.dart';
import '../state/guard_state.dart';
import '../theme/tokens.dart';
import '../ui/parts.dart';

/// One plain screen per the brief: each permission, why it's needed, and a button
/// that opens the OS page. Status refreshes when the user comes back.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GuardScope.of(context);
    final c = ControllerScope.of(context);
    final supported = c.bridge.supportedPermissions.toList()..sort((a, b) => a.index.compareTo(b.index));

    final shade = Shade.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, Tokens.gutter),
        children: [
          const PageHead('Permissions', sub: 'Each one has a job. Without it, part of Guard stops working, and Home will say so.'),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              for (var i = 0; i < supported.length; i++) ...[
                if (i > 0) Divider(height: 1, color: shade.hairline),
                Padding(
                  key: Key('perm-${supported[i].name}'),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(supported[i].label, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 15, fontWeight: FontWeight.w600, color: shade.text)),
                        const SizedBox(height: 2),
                        Text(supported[i].why, style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 12, color: shade.muted)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    if (state.permissions[supported[i]] == true)
                      Icon(Icons.check_circle, color: shade.accent, size: 22)
                    else
                      OutlinedButton(
                        key: Key('grant-${supported[i].name}'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () => c.requestPermission(supported[i]),
                        child: const Text('Turn on'),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
          const Promise(text: 'We never read your trades or log into any account.'),
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
    return Panel(
      key: const Key('permission-banner'),
      accent: Tokens.amber,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen())),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(missing.length == 1 ? 'One thing to turn on' : '${missing.length} things to turn on',
                style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 14, fontWeight: FontWeight.w700, color: Tokens.amber)),
            const SizedBox(height: 2),
            Text(missing.map((p) => p.label).join(' · '), style: TextStyle(fontFamily: Tokens.bodyFamily, fontSize: 13, color: Shade.of(context).text)),
          ]),
        ),
        Icon(Icons.chevron_right, size: 18, color: Shade.of(context).muted),
      ]),
    );
  }
}
