import 'package:flutter/material.dart';
import 'package:tekmerion/src/features/reminder/application/reminder_view_service.dart';
import 'package:tekmerion/src/features/reminder/presentation/models/reminder_card_view_model.dart';
import 'package:tekmerion/src/features/reminder/presentation/widgets/reminder_card.dart';

class TodayRemindersScreen extends StatefulWidget {
  const TodayRemindersScreen({
    super.key,
    required this.viewService,
    required this.gracePeriod,
    this.onAcknowledge,
    this.onDismiss,
    this.onComplete,
  });

  final ReminderViewService viewService;
  final Duration gracePeriod;
  final void Function(ReminderCardViewModel)? onAcknowledge;
  final void Function(ReminderCardViewModel)? onDismiss;
  final void Function(ReminderCardViewModel)? onComplete;

  @override
  State<TodayRemindersScreen> createState() => _TodayRemindersScreenState();
}

class _TodayRemindersScreenState extends State<TodayRemindersScreen> {
  late Future<List<ReminderCardViewModel>> _viewModelsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _viewModelsFuture = widget.viewService.getTodayViewModels(
        DateTime.now().toUtc(),
        widget.gracePeriod,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<List<ReminderCardViewModel>>(
        future: _viewModelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reminders for today.'));
          }

          final viewModels = snapshot.data!;
          return ListView.builder(
            itemCount: viewModels.length,
            itemBuilder: (context, index) {
              final vm = viewModels[index];
              return ReminderCard(
                viewModel: vm,
                onAcknowledge: widget.onAcknowledge != null ? () => widget.onAcknowledge!(vm) : null,
                onDismiss: widget.onDismiss != null ? () => widget.onDismiss!(vm) : null,
                onComplete: widget.onComplete != null ? () => widget.onComplete!(vm) : null,
              );
            },
          );
        },
      ),
    );
  }
}
