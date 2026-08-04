import 'package:flutter/material.dart';

class TekmerionApp extends StatelessWidget {
  const TekmerionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tekmerion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF355C4D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8CB8A3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AgreementHomeScreen(),
    );
  }
}

class AgreementHomeScreen extends StatelessWidget {
  const AgreementHomeScreen({super.key});

  static const List<_LoopStep> _steps = <_LoopStep>[
    _LoopStep(Icons.upload_file, 'Upload', 'Preserve the signed agreement.'),
    _LoopStep(Icons.fact_check_outlined, 'Confirm',
        'Review obligations and their source clauses.'),
    _LoopStep(Icons.notifications_none, 'Remember',
        'Receive reminders from confirmed rules.'),
    _LoopStep(Icons.add_a_photo_outlined, 'Document',
        'Capture performance, issues, and evidence.'),
    _LoopStep(Icons.link, 'Connect', 'Link each record to the agreement.'),
    _LoopStep(Icons.inventory_2_outlined, 'Export',
        'Carry a readable Record Package to a third party.'),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tekmerion'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              'What does this agreement require now?',
              style: textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Upload the agreement once. Tekmerion helps you remember what it requires, document how you keep it, and preserve a trustworthy record.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            for (final _LoopStep step in _steps) ...<Widget>[
              Card(
                child: ListTile(
                  leading: Icon(step.icon),
                  title: Text(step.title),
                  subtitle: Text(step.description),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Add an agreement'),
            ),
            const SizedBox(height: 12),
            Text(
              'Phase 1 bootstrap: this screen intentionally exposes the frozen loop before storage and import are connected.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoopStep {
  const _LoopStep(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}
