import 'timeline_event.dart';

abstract class TimelineRepository {
  /// Fetches a chronologically ordered list of events for the specified agreement.
  /// Typically newest first (descending by recordedAt).
  Future<List<TimelineEvent>> getTimelineForAgreement(String agreementId);
}
