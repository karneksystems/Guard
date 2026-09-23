import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Hub placeholder. Reachable only when kHubEnabled is true. Ships dark.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(Tokens.gutter),
      children: [
        Text('Profile', style: text.headlineMedium),
        const SizedBox(height: Tokens.gutter),
        const Text('The hub lives here later: profile, payout proofs, leaderboard.'),
      ],
    );
  }
}
