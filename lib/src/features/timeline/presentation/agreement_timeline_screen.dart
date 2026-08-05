import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tekmerion/src/features/export/application/export_share_adapter.dart';
import 'package:tekmerion/src/features/export/application/record_package_export_service.dart';
import 'package:tekmerion/src/features/export/domain/export_package_repository.dart';
import 'package:tekmerion/src/features/export/presentation/record_package_export_screen.dart';
import '../../agreement/domain/agreement.dart';
import '../application/agreement_timeline_service.dart';
import '../domain/timeline_event.dart';

enum TimelineFilter {
  all,
  clauses,
  obligations,
  records,
  evidence,
  exports,
}

class AgreementTimelineScreen extends StatefulWidget {
  const AgreementTimelineScreen({
    super.key,
    required this.agreement,
    required this.timelineService,
    required this.exportService,
    required this.exportPackageRepository,
    required this.exportShareAdapter,
  });

  final Agreement agreement;
  final AgreementTimelineService timelineService;
  final RecordPackageExportService exportService;
  final ExportPackageRepository exportPackageRepository;
  final ExportShareAdapter exportShareAdapter;

  @override
  State<AgreementTimelineScreen> createState() =>
      _AgreementTimelineScreenState();
}

class _AgreementTimelineScreenState extends State<AgreementTimelineScreen> {
  TimelineFilter _currentFilter = TimelineFilter.all;
  bool _isLoading = true;
  Map<DateTime, List<TimelineEvent>> _groupedEvents = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final groupedEvents =
          await widget.timelineService.getGroupedTimeline(widget.agreement.id);
      setState(() {
        _groupedEvents = groupedEvents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<TimelineEvent> _filterEvents(List<TimelineEvent> events) {
    if (_currentFilter == TimelineFilter.all) return events;
    return events.where((event) {
      switch (_currentFilter) {
        case TimelineFilter.clauses:
          return event.sourceObjectType == 'Clause';
        case TimelineFilter.obligations:
          return event.sourceObjectType == 'Obligation';
        case TimelineFilter.records:
          return event.sourceObjectType == 'RecordEntry';
        case TimelineFilter.evidence:
          return event.sourceObjectType == 'EvidenceAsset';
        case TimelineFilter.exports:
          return event.sourceObjectType == 'ExportPackage';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agreement Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive),
            tooltip: 'Export Record Package',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecordPackageExportScreen(
                    agreementId: widget.agreement.id,
                    agreementTitle: widget.agreement.title,
                    exportService: widget.exportService,
                    exportPackageRepository: widget.exportPackageRepository,
                    exportShareAdapter: widget.exportShareAdapter,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<TimelineFilter>(
            initialValue: _currentFilter,
            onSelected: (filter) {
              setState(() {
                _currentFilter = filter;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: TimelineFilter.all, child: Text('All')),
              PopupMenuItem(
                value: TimelineFilter.clauses,
                child: Text('Clauses'),
              ),
              PopupMenuItem(
                value: TimelineFilter.obligations,
                child: Text('Obligations'),
              ),
              PopupMenuItem(
                value: TimelineFilter.records,
                child: Text('Records'),
              ),
              PopupMenuItem(
                value: TimelineFilter.evidence,
                child: Text('Evidence'),
              ),
              PopupMenuItem(
                value: TimelineFilter.exports,
                child: Text('Exports'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text('Error: \$_errorMessage'));
    }
    if (_groupedEvents.isEmpty) {
      return const Center(
        child: Text(
          'No events have occurred yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final filteredGroups = <DateTime, List<TimelineEvent>>{};
    for (final entry in _groupedEvents.entries) {
      final filtered = _filterEvents(entry.value);
      if (filtered.isNotEmpty) {
        filteredGroups[entry.key] = filtered;
      }
    }

    if (filteredGroups.isEmpty) {
      return const Center(
        child: Text(
          'No events match the current filter.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final date = filteredGroups.keys.elementAt(index);
        final events = filteredGroups[date]!;
        return _buildDateGroup(date, events);
      },
    );
  }

  Widget _buildDateGroup(DateTime date, List<TimelineEvent> events) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            dateFormat.format(date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...events.map(_buildEventCard),
        const Divider(),
      ],
    );
  }

  Widget _buildEventCard(TimelineEvent event) {
    final timeFormat = DateFormat('h:mm a');
    IconData iconData;
    switch (event.sourceObjectType) {
      case 'Agreement':
      case 'AgreementVersion':
        iconData = Icons.description;
        break;
      case 'Clause':
        iconData = Icons.article;
        break;
      case 'Obligation':
        iconData = Icons.assignment;
        break;
      case 'RecordEntry':
        iconData = Icons.verified;
        break;
      case 'EvidenceAsset':
        iconData = Icons.attach_file;
        break;
      case 'ExportPackage':
        iconData = Icons.download;
        break;
      default:
        iconData = Icons.event;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(
          iconData,
          color: event.integrityState == TimelineIntegrityState.verified
              ? Colors.green
              : Colors.orange,
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${timeFormat.format(event.recordedAt.toLocal())} • ${event.summary}',
        ),
        trailing: event.integrityState == TimelineIntegrityState.verified
            ? const Tooltip(
                message: 'Verified',
                child: Icon(Icons.shield, color: Colors.green, size: 16),
              )
            : const Tooltip(
                message: 'Unverified',
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.orange,
                  size: 16,
                ),
              ),
        onTap: () {
          // Future: Navigate to the specific object
        },
      ),
    );
  }
}
