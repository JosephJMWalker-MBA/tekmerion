import 'package:meta/meta.dart';

enum ObligationSourceType {
  contractual,
  userEntered,
  inferredButConfirmed,
  statutory,
  externalAuthority,
}

enum ObligationStatus {
  draft,
  confirmed,
  upcoming,
  due,
  fulfilled,
  reported,
  awaitingResponse,
  disputed,
  notApplicable,
  superseded,
}

@immutable
class Obligation {
  const Obligation({
    required this.id,
    required this.agreementId,
    this.sourceClauseId,
    required this.sourceType,
    this.responsiblePartyId,
    this.benefitedPartyId,
    required this.title,
    required this.description,
    required this.obligationCategory,
    required this.status,
    this.confirmedAt,
    this.confirmedByPartyId,
    this.supersededByObligationId,
    required this.createdAt,
  });

  final String id;
  final String agreementId;
  final String? sourceClauseId;
  final ObligationSourceType sourceType;
  final String? responsiblePartyId;
  final String? benefitedPartyId;
  final String title;
  final String description;
  final String obligationCategory;
  final ObligationStatus status;
  final DateTime? confirmedAt;
  final String? confirmedByPartyId;
  final String? supersededByObligationId;
  final DateTime createdAt;

  Obligation copyWith({
    String? id,
    String? agreementId,
    String? sourceClauseId,
    ObligationSourceType? sourceType,
    String? responsiblePartyId,
    String? benefitedPartyId,
    String? title,
    String? description,
    String? obligationCategory,
    ObligationStatus? status,
    DateTime? confirmedAt,
    String? confirmedByPartyId,
    String? supersededByObligationId,
    DateTime? createdAt,
  }) {
    return Obligation(
      id: id ?? this.id,
      agreementId: agreementId ?? this.agreementId,
      sourceClauseId: sourceClauseId ?? this.sourceClauseId,
      sourceType: sourceType ?? this.sourceType,
      responsiblePartyId: responsiblePartyId ?? this.responsiblePartyId,
      benefitedPartyId: benefitedPartyId ?? this.benefitedPartyId,
      title: title ?? this.title,
      description: description ?? this.description,
      obligationCategory: obligationCategory ?? this.obligationCategory,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedByPartyId: confirmedByPartyId ?? this.confirmedByPartyId,
      supersededByObligationId:
          supersededByObligationId ?? this.supersededByObligationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Obligation &&
        other.id == id &&
        other.agreementId == agreementId &&
        other.sourceClauseId == sourceClauseId &&
        other.sourceType == sourceType &&
        other.responsiblePartyId == responsiblePartyId &&
        other.benefitedPartyId == benefitedPartyId &&
        other.title == title &&
        other.description == description &&
        other.obligationCategory == obligationCategory &&
        other.status == status &&
        other.confirmedAt == confirmedAt &&
        other.confirmedByPartyId == confirmedByPartyId &&
        other.supersededByObligationId == supersededByObligationId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      agreementId,
      sourceClauseId,
      sourceType,
      responsiblePartyId,
      benefitedPartyId,
      title,
      description,
      obligationCategory,
      status,
      confirmedAt,
      confirmedByPartyId,
      supersededByObligationId,
      createdAt,
    );
  }
}
