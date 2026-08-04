import 'evidence_reference.dart';

enum RecordState {
  draft,
  finalized,
}

enum RecordType {
  firsthandObservation,
  performance,
  payment,
  communicationSent,
  communicationReceived,
  importedSource,
  otherPartyAssertion,
  userInterpretation,
  resolution,
  correction,
}

class RecordEntry {
  const RecordEntry({
    required this.id,
    required this.workspaceId,
    required this.agreementId,
    required this.agreementVersionId,
    required this.recordType,
    required this.title,
    required this.factualDescription,
    required this.occurredAt,
    required this.recordedAt,
    required this.timezone,
    required this.createdByPartyId,
    required this.state,
    this.obligationId,
    this.sourceClauseId,
    this.interpretationText,
    this.correctsRecordEntryId,
    this.finalizedAt,
    this.recordHash,
    this.previousChainHash,
    this.chainHash,
    this.evidence = const <EvidenceReference>[],
  });

  final String id;
  final String workspaceId;
  final String agreementId;
  final String agreementVersionId;
  final String? obligationId;
  final String? sourceClauseId;
  final RecordType recordType;
  final String title;
  final String factualDescription;
  final String? interpretationText;
  final DateTime occurredAt;
  final DateTime recordedAt;
  final String timezone;
  final String createdByPartyId;
  final String? correctsRecordEntryId;
  final DateTime? finalizedAt;
  final String? recordHash;
  final String? previousChainHash;
  final String? chainHash;
  final RecordState state;
  final List<EvidenceReference> evidence;

  bool get isFinalized => state == RecordState.finalized;

  RecordEntry copyWith({
    String? title,
    String? factualDescription,
    String? interpretationText,
    DateTime? occurredAt,
    DateTime? finalizedAt,
    String? recordHash,
    String? previousChainHash,
    String? chainHash,
    RecordState? state,
    List<EvidenceReference>? evidence,
  }) {
    return RecordEntry(
      id: id,
      workspaceId: workspaceId,
      agreementId: agreementId,
      agreementVersionId: agreementVersionId,
      obligationId: obligationId,
      sourceClauseId: sourceClauseId,
      recordType: recordType,
      title: title ?? this.title,
      factualDescription: factualDescription ?? this.factualDescription,
      interpretationText: interpretationText ?? this.interpretationText,
      occurredAt: occurredAt ?? this.occurredAt,
      recordedAt: recordedAt,
      timezone: timezone,
      createdByPartyId: createdByPartyId,
      correctsRecordEntryId: correctsRecordEntryId,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      recordHash: recordHash ?? this.recordHash,
      previousChainHash: previousChainHash ?? this.previousChainHash,
      chainHash: chainHash ?? this.chainHash,
      state: state ?? this.state,
      evidence: evidence ?? this.evidence,
    );
  }
}
