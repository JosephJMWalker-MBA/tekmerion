import 'package:meta/meta.dart';

enum ClauseReviewState {
  draft,
  confirmed,
  corrected,
  rejected,
}

/// A Clause is a discrete segment of governed text bound to a specific AgreementVersion.
@immutable
class Clause {
  const Clause({
    required this.id,
    required this.agreementVersionId,
    this.parentClauseId,
    this.heading,
    this.clauseNumber,
    required this.sourceText,
    this.normalizedText,
    required this.pageStart,
    required this.pageEnd,
    this.characterStart,
    this.characterEnd,
    this.parseConfidence,
    required this.reviewState,
    required this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String agreementVersionId;
  final String? parentClauseId;
  final String? heading;
  final String? clauseNumber;
  final String sourceText;
  final String? normalizedText;
  final int pageStart;
  final int pageEnd;
  final int? characterStart;
  final int? characterEnd;
  final double? parseConfidence;
  final ClauseReviewState reviewState;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  Clause copyWith({
    String? id,
    String? agreementVersionId,
    String? parentClauseId,
    String? heading,
    String? clauseNumber,
    String? sourceText,
    String? normalizedText,
    int? pageStart,
    int? pageEnd,
    int? characterStart,
    int? characterEnd,
    double? parseConfidence,
    ClauseReviewState? reviewState,
    DateTime? createdAt,
    DateTime? confirmedAt,
  }) {
    return Clause(
      id: id ?? this.id,
      agreementVersionId: agreementVersionId ?? this.agreementVersionId,
      parentClauseId: parentClauseId ?? this.parentClauseId,
      heading: heading ?? this.heading,
      clauseNumber: clauseNumber ?? this.clauseNumber,
      sourceText: sourceText ?? this.sourceText,
      normalizedText: normalizedText ?? this.normalizedText,
      pageStart: pageStart ?? this.pageStart,
      pageEnd: pageEnd ?? this.pageEnd,
      characterStart: characterStart ?? this.characterStart,
      characterEnd: characterEnd ?? this.characterEnd,
      parseConfidence: parseConfidence ?? this.parseConfidence,
      reviewState: reviewState ?? this.reviewState,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Clause &&
        other.id == id &&
        other.agreementVersionId == agreementVersionId &&
        other.parentClauseId == parentClauseId &&
        other.heading == heading &&
        other.clauseNumber == clauseNumber &&
        other.sourceText == sourceText &&
        other.normalizedText == normalizedText &&
        other.pageStart == pageStart &&
        other.pageEnd == pageEnd &&
        other.characterStart == characterStart &&
        other.characterEnd == characterEnd &&
        other.parseConfidence == parseConfidence &&
        other.reviewState == reviewState &&
        other.createdAt == createdAt &&
        other.confirmedAt == confirmedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      agreementVersionId,
      parentClauseId,
      heading,
      clauseNumber,
      sourceText,
      normalizedText,
      pageStart,
      pageEnd,
      characterStart,
      characterEnd,
      parseConfidence,
      reviewState,
      createdAt,
      confirmedAt,
    );
  }
}
