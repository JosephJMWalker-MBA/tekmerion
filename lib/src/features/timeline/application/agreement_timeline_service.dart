import '../domain/timeline_event.dart';
import '../domain/timeline_repository.dart';

class AgreementTimelineService {
  AgreementTimelineService({
    required TimelineRepository timelineRepository,
  }) : _timelineRepository = timelineRepository;

  final TimelineRepository _timelineRepository;

  /// Fetches the timeline for an agreement, groups the events by calendar day,
  /// and returns them sorted with the newest days first.
  Future<Map<DateTime, List<TimelineEvent>>> getGroupedTimeline(
    String agreementId,
  ) async {
    final events =
        await _timelineRepository.getTimelineForAgreement(agreementId);

    // Group by calendar day (stripping time)
    final Map<DateTime, List<TimelineEvent>> grouped = {};
    for (final event in events) {
      final date = DateTime(
        event.recordedAt.year,
        event.recordedAt.month,
        event.recordedAt.day,
      );
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(event);
    }

    // Sort days descending
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<DateTime, List<TimelineEvent>> sortedGrouped = {};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }
}
