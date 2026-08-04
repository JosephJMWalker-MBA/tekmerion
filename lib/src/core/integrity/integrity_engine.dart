abstract interface class IntegrityEngine {
  /// Hashes the canonical byte representation of a record.
  String hashRecord(List<int> canonicalBytes);

  /// Hashes a chain link combining the previous hash and the current record hash.
  String hashChain({
    required String? previousChainHash,
    required String recordHash,
  });
}
