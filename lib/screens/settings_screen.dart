import 'package:flutter/material.dart';
import '../services/deepseek_service.dart';
import '../services/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsController settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final aiConfigured = DeepSeekService().isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel('Appearance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme'),
                      const SizedBox(height: 12),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) =>
                            settings.setThemeMode(s.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('AI assistant'),
              Card(
                child: ListTile(
                  leading: Icon(
                    aiConfigured
                        ? Icons.auto_awesome
                        : Icons.auto_awesome_outlined,
                    color: aiConfigured ? scheme.primary : scheme.outline,
                  ),
                  title: Text(aiConfigured ? 'Enabled' : 'Disabled'),
                  subtitle: Text(
                    aiConfigured
                        ? 'Writing assistant is ready to use in the editor.'
                        : 'Set AI_PROXY_URL in the app config to enable.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel('About'),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.sticky_note_2_outlined),
                      title: Text('NoteHeaven'),
                      subtitle: Text('Version 1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Your notes stay on your device'),
                      subtitle: const Text(
                          'Notes are stored locally. Sharing is peer-to-peer over your local network.'),
                      isThreeLine: false,
                      onTap: null,
                      textColor: scheme.onSurface,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
