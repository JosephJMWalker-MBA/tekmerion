import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/core/integrity/sha256_integrity_engine.dart';

void main() {
  group('Sha256IntegrityEngine', () {
    const engine = Sha256IntegrityEngine();

    test('hashes empty bytes correctly', () {
      final digest = engine.hashRecord([]);
      expect(
        digest,
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('hashes UTF-8 bytes for "abc"', () {
      final bytes = utf8.encode('abc');
      final digest = engine.hashRecord(bytes);
      expect(
        digest,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('hashes a representative binary byte sequence', () {
      final bytes = <int>[0x00, 0xFF, 0x5A, 0xA5];
      final digest = engine.hashRecord(bytes);
      expect(
        digest,
        '86b8b09d3b5b6348efc6cc053dcc02a6cece908bfcf605d63ad1c16503c4fc37',
      );
    });

    test('repeated hashing of identical bytes produces identical output', () {
      final bytes = utf8.encode('identical');
      final first = engine.hashRecord(bytes);
      final second = engine.hashRecord(bytes);
      expect(first, second);
    });

    test('changing one byte changes the digest', () {
      final bytes = utf8.encode('identical');
      final original = engine.hashRecord(bytes);

      final modifiedBytes = List<int>.from(bytes);
      modifiedBytes[0] = modifiedBytes[0] + 1;
      
      final modified = engine.hashRecord(modifiedBytes);
      expect(original, isNot(modified));
    });

    test('chain hash concatenates previous and current', () {
      final chain = engine.hashChain(
        previousChainHash: 'prev',
        recordHash: 'curr',
      );
      // sha256('prevcurr')
      expect(
        chain,
        'f58f55365db01b1fc7e8a93db2e8de7b154ce8a30dbf1345d3e230ce748981e4',
      );
    });

    test('chain hash without previous just hashes current', () {
      final chain = engine.hashChain(
        previousChainHash: null,
        recordHash: 'curr',
      );
      // sha256('curr')
      expect(
        chain,
        'da2f483a992bc96cd18b41ca0fccfca0835f137e50c41031c5188f912c75249b',
      );
    });
  });
}
