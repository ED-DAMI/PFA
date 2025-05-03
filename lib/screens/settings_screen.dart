import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement settings options (Theme, Language, Notifications, Account)

    return Scaffold(
        appBar: AppBar(
          title: const Text('Paramètres'),
        ),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Langue'),
              subtitle: const Text('Français'), // Example
              onTap: () { /* TODO: Change language */ },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Thème'),
              subtitle: const Text('Système'), // Example
              onTap: () { /* TODO: Change theme (Light/Dark/System) */ },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notifications'),
              trailing: Switch(value: true, onChanged: (val) { /* TODO: Toggle notifications */ } ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Gestion du compte'),
              onTap: () { /* TODO: Navigate to account management page */ },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('À propos'),
              onTap: () { /* TODO: Show about dialog/screen */ },
            ),
          ],
        )
    );
  }
}