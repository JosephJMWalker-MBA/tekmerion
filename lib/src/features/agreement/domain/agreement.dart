enum AgreementStatus {
  setup,
  active,
  archived,
}

class Agreement {
  const Agreement({
    required this.id,
    required this.title,
    required this.agreementType,
    required this.status,
    required this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String agreementType;
  final AgreementStatus status;
  final DateTime createdAt;
  final DateTime? archivedAt;
}
