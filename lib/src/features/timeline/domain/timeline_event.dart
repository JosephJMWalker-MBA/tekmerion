import 'package:meta/meta.dart';

enum TimelineEventType {
  agreementImported,
  agreementVersionCreated,
  clauseConfirmed,
  obligationConfirmed,
  obligationCompleted,
  recordFinalized,
  evidenceAttached,
  exportGenerated,
}

enum TimelineEventProvenance {
  system,
  user,
}

enum TimelineIntegrityState {
  verified,
  unverified, // E.g., draft or pending records, though they shouldn't show up usually
  compromised,
}

@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.agreementId,
    required this.eventType,
    required this.occurredAt,
    required this.recordedAt,
    required this.title,
    required this.summary,
    required this.provenanceType,
    required this.sourceObjectType,
    required this.sourceObjectId,
    required this.integrityState,
    this.displayPriority = 0,
    this.metadata = const {},
  });

  final String id;
  final String agreementId;
  final TimelineEventType eventType;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final String title;
  final String summary;
  final TimelineEventProvenance provenanceType;
  final String
      sourceObjectType; // e.g. 'Agreement', 'Clause', 'Obligation', 'RecordEntry'
  final String sourceObjectId;
  final TimelineIntegrityState integrityState;
  final int displayPriority;
  final Map<String, dynamic> metadata;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineEvent &&
        other.id == id &&
        other.agreementId == agreementId &&
        other.eventType == eventType &&
        other.occurredAt == occurredAt &&
        other.recordedAt == recordedAt &&
        other.title == title &&
        other.summary == summary &&
        other.provenanceType == provenanceType &&
        other.sourceObjectType == sourceObjectType &&
        other.sourceObjectId == sourceObjectId &&
        other.integrityState == integrityState &&
        other.displayPriority == displayPriority;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      agreementId,
      eventType,
      occurredAt,
      recordedAt,
      title,
      summary,
      provenanceType,
      sourceObjectType,
      sourceObjectId,
      integrityState,
      displayPriority,
    );
  }
}
