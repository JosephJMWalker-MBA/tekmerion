import 'package:meta/meta.dart';

@immutable
class ExportPackage {
  const ExportPackage({
    required this.id,
    required this.agreementId,
    required this.generatedAt,
    required this.format,
    required this.filterParametersJson,
    required this.manifestSha256,
    required this.managedStorageIdentifier,
    required this.generatorVersion,
    required this.completenessState,
    required this.warningCount,
  });

  factory ExportPackage.fromMap(Map<String, dynamic> map) {
    return ExportPackage(
      id: map['id'] as String,
      agreementId: map['agreement_id'] as String,
      generatedAt: DateTime.parse(map['generated_at'] as String),
      format: map['format'] as String,
      filterParametersJson: map['filter_parameters_json'] as String,
      manifestSha256: map['manifest_sha256'] as String,
      managedStorageIdentifier: map['managed_storage_identifier'] as String,
      generatorVersion: map['generator_version'] as String,
      completenessState: map['completeness_state'] as String,
      warningCount: map['warning_count'] as int,
    );
  }
  final String id;
  final String agreementId;
  final DateTime generatedAt;
  final String format;
  final String filterParametersJson;
  final String manifestSha256;
  final String managedStorageIdentifier;
  final String generatorVersion;
  final String completenessState;
  final int warningCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'agreement_id': agreementId,
      'generated_at': generatedAt.toIso8601String(),
      'format': format,
      'filter_parameters_json': filterParametersJson,
      'manifest_sha256': manifestSha256,
      'managed_storage_identifier': managedStorageIdentifier,
      'generator_version': generatorVersion,
      'completeness_state': completenessState,
      'warning_count': warningCount,
    };
  }
}

@immutable
class ExportScope {
  const ExportScope({
    required this.scopeType,
    required this.completeAgreementChain,
    this.filters = const {},
    this.excludedItemCount,
    this.completenessWarnings = const [],
  });

  factory ExportScope.complete() {
    return const ExportScope(
      scopeType: 'full_agreement',
      completeAgreementChain: true,
    );
  }
  final String scopeType;
  final bool completeAgreementChain;
  final Map<String, dynamic> filters;
  final int? excludedItemCount;
  final List<String> completenessWarnings;

  Map<String, dynamic> toJson() {
    return {
      'scope_type': scopeType,
      'complete_agreement_chain': completeAgreementChain,
      'filters': filters,
      if (excludedItemCount != null) 'excluded_item_count': excludedItemCount,
      if (completenessWarnings.isNotEmpty)
        'completeness_warnings': completenessWarnings,
    };
  }
}
