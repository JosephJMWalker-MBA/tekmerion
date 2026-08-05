import 'package:flutter_test/flutter_test.dart';
import 'package:tekmerion/src/features/reminder/domain/notification_id_generator.dart';

void main() {
  group('NotificationIdGenerator', () {
    test('same occurrence receives the same ID', () {
      final key = 'test-occurrence-key';
      final id1 = NotificationIdGenerator.generateId(key);
      final id2 = NotificationIdGenerator.generateId(key);
      expect(id1, id2);
    });

    test('different occurrences normally receive different IDs', () {
      final id1 = NotificationIdGenerator.generateId('key-1');
      final id2 = NotificationIdGenerator.generateId('key-2');
      expect(id1, isNot(id2));
    });

    test('forced collision resolves deterministically with attempt counter',
        () {
      final key = 'forced-collision-test';
      final id0 = NotificationIdGenerator.generateId(key, attempt: 0);
      final id1 = NotificationIdGenerator.generateId(key, attempt: 1);
      final id2 = NotificationIdGenerator.generateId(key, attempt: 2);

      expect(id0, isNot(id1));
      expect(id0, isNot(id2));
      expect(id1, isNot(id2));

      // Attempt 1 should always produce the same ID
      final id1Again = NotificationIdGenerator.generateId(key, attempt: 1);
      expect(id1, id1Again);
    });

    test('no negative IDs are emitted and fit in 31 bits', () {
      for (int i = 0; i < 1000; i++) {
        final id = NotificationIdGenerator.generateId('test-key-$i');
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });
}
