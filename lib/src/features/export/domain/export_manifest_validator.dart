import 'dart:convert';
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

class ExportManifestValidator {
  ExportManifestValidator(this.schema);
  final JsonSchema schema;

  List<String> validate(Map<String, dynamic> manifestJson) {
    final errors = <String>[];

    // 1. JSON Schema Draft Validation
    // The `json_schema` package does not support Draft 2020-12 entirely.
    // It will catch missing required fields, additional properties, and type mismatches.
    final validationResult =
        schema.validate(jsonDecode(jsonEncode(manifestJson)));
    if (!validationResult.isValid) {
      for (final error in validationResult.errors) {
        errors.add(error.toString());
      }
    }

    // 2. Supplemental Validation
    _validateUuid(manifestJson['package_id']?.toString(), 'package_id', errors);
    _validateTimestamp(
      manifestJson['generated_at']?.toString(),
      'generated_at',
      errors,
    );

    final integrity = manifestJson['integrity'] as Map<String, dynamic>?;
    if (integrity != null) {
      _validateSha256(
        integrity['manifest_sha256']?.toString(),
        'integrity.manifest_sha256',
        errors,
      );
    }

    final files = manifestJson['files'] as List<dynamic>?;
    if (files != null) {
      final seenPaths = <String>{};
      for (var i = 0; i < files.length; i++) {
        final file = files[i] as Map<String, dynamic>;
        final path = file['path']?.toString();
        _validatePath(path, 'files[$i].path', seenPaths, errors);
        _validateSha256(file['sha256']?.toString(), 'files[$i].sha256', errors);
      }
    }

    return errors;
  }

  void _validateUuid(String? value, String field, List<String> errors) {
    if (value == null) return;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(value)) {
      errors.add('$field is not a valid UUID: $value');
    }
  }

  void _validateTimestamp(String? value, String field, List<String> errors) {
    if (value == null) return;
    try {
      DateTime.parse(value);
      if (!value.contains('T') || !value.endsWith('Z')) {
        errors.add(
          '$field must be in strict RFC 3339 format with Z timezone: $value',
        );
      }
    } catch (e) {
      errors.add('$field is not a valid RFC 3339 timestamp: $value');
    }
  }

  void _validateSha256(String? value, String field, List<String> errors) {
    if (value == null) return;
    final sha256Regex = RegExp(r'^[a-f0-9]{64}$');
    if (!sha256Regex.hasMatch(value)) {
      errors.add(
        '$field is not a valid lowercase 64-character SHA-256 hash: $value',
      );
    }
  }

  void _validatePath(
    String? path,
    String field,
    Set<String> seenPaths,
    List<String> errors,
  ) {
    if (path == null || path.isEmpty) {
      errors.add('$field is empty');
      return;
    }
    if (path.startsWith('/')) {
      errors.add('$field is an absolute path: $path');
    }
    if (path.contains(r'\')) {
      errors.add('$field contains backslashes: $path');
    }
    if (path.contains('..') || path.contains('./')) {
      errors.add('$field contains unsafe traversal segments: $path');
    }

    // Normalize path to check for uniqueness
    final normalized = p.posix.normalize(path);
    if (seenPaths.contains(normalized)) {
      errors.add('$field is a duplicate path: $path');
    }
    seenPaths.add(normalized);
  }
}
