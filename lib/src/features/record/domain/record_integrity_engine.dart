abstract interface class RecordIntegrityEngine {
  String hashRecord(List<int> canonicalBytes);

  String hashChain({
    required String? previousChainHash,
    required String recordHash,
  });
}
