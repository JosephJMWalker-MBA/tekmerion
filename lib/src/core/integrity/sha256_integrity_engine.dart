import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'integrity_engine.dart';

class Sha256IntegrityEngine implements IntegrityEngine {
  const Sha256IntegrityEngine();

  @override
  String hashRecord(List<int> canonicalBytes) {
    return sha256.convert(canonicalBytes).toString();
  }

  @override
  String hashChain({
    required String? previousChainHash,
    required String recordHash,
  }) {
    final String chainData = previousChainHash != null
        ? '$previousChainHash$recordHash'
        : recordHash;
    return sha256.convert(utf8.encode(chainData)).toString();
  }
}
