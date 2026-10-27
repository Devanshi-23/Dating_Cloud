import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../app/config/environment.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/errors/failure.dart';
import '../mock/mock_settings.dart';
import 'developer_tools_view_model.dart';

/// Reachable only when `AppConfig.showDeveloperTools` is true (route guard).
class DeveloperToolsView extends ConsumerWidget {
  const DeveloperToolsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          ListTile(
            title: const Text('Environment'),
            trailing: Text(config.env.name),
          ),
          ListTile(
            title: const Text('Data mode'),
            trailing: Text(config.dataMode.name),
          ),
          if (config.dataMode == DataMode.hybrid)
            ListTile(
              title: const Text('Mocked features'),
              subtitle: Text(
                config.hybridMockFeatures.map((f) => f.name).join(', '),
              ),
            ),
          if (config.usesAnyApi)
            ListTile(
              title: const Text('API base URL'),
              subtitle: Text(config.apiBaseUrl),
            ),
          const Divider(),
          if (!config.usesAnyMock)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Mock controls are unavailable because every feature uses the real API.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            const _MockControls(),
        ],
      ),
    );
  }
}

class _MockControls extends ConsumerWidget {
  const _MockControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(developerToolsViewModelProvider);
    final viewModel = ref.read(developerToolsViewModelProvider.notifier);
    final latencyMs = settings.latency.inMilliseconds
        .toDouble()
        .clamp(0, 3000)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Simulated latency'),
          trailing: Text('${latencyMs.round()} ms'),
        ),
        Slider(
          value: latencyMs,
          max: 3000,
          divisions: 30,
          label: '${latencyMs.round()} ms',
          onChanged: (v) =>
              viewModel.setLatency(Duration(milliseconds: v.round())),
        ),
        ListTile(
          title: const Text('Failure injection'),
          trailing: DropdownButton<MockFailureMode>(
            value: settings.failureMode,
            onChanged: (mode) => viewModel.setFailureMode(mode!),
            items: const [
              DropdownMenuItem(value: MockFailureMode.none, child: Text('Off')),
              DropdownMenuItem(
                value: MockFailureMode.nextRequest,
                child: Text('Next request'),
              ),
              DropdownMenuItem(
                value: MockFailureMode.allRequests,
                child: Text('All requests'),
              ),
            ],
          ),
        ),
        ListTile(
          title: const Text('Failure type'),
          trailing: DropdownButton<ErrorCode>(
            value: settings.failureCode,
            onChanged: (code) => viewModel.setFailureCode(code!),
            items: [
              for (final code in const [
                ErrorCode.networkError,
                ErrorCode.serverError,
                ErrorCode.rateLimited,
                ErrorCode.unauthenticated,
              ])
                DropdownMenuItem(value: code, child: Text(code.wire)),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Force empty lists'),
          subtitle: const Text('Discovery, matches and chats return no items'),
          value: settings.forceEmpty,
          onChanged: viewModel.setForceEmpty,
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: OutlinedButton.icon(
            key: const Key('dev.reset'),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Reset mock data'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Reset mock data?'),
                  content: const Text(
                    'Restores all fixtures (swipes, matches, messages, purchases), '
                    'forgets the account saved after setup, and signs you out.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await viewModel.resetMockData();
            },
          ),
        ),
      ],
    );
  }
}
