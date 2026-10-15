import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('QaRegisterInput model', () {
    test('defaults to 0.0 openingFloatAmount and empty notes', () {
      const input = QaRegisterInput();
      expect(input.openingFloatAmount, 0.0);
      expect(input.notes, isEmpty);
      expect(input.isValid, isTrue);
    });

    test('clamps amount to 0..5000 in fromJson', () {
      final negative = QaRegisterInput.fromJson(<String, Object?>{
        'openingFloatAmount': -100,
        'notes': 'test',
      });
      expect(negative.openingFloatAmount, 0.0);

      final overLimit = QaRegisterInput.fromJson(<String, Object?>{
        'openingFloatAmount': 7500,
        'notes': 'test',
      });
      expect(overLimit.openingFloatAmount, 5000.0);

      final valid = QaRegisterInput.fromJson(<String, Object?>{
        'openingFloatAmount': 2500,
        'notes': 'valid',
      });
      expect(valid.openingFloatAmount, 2500.0);
      expect(valid.notes, 'valid');
    });

    test('serializes to and from json accurately', () {
      const original = QaRegisterInput(
        openingFloatAmount: 1500.0,
        closeTotalAmount: 2500.0,
        notes: 'Morning shift',
        closeNotes: 'Evening shift',
      );
      final json = original.toJson();
      final restored = QaRegisterInput.fromJson(json);
      expect(restored.openingFloatAmount, 1500.0);
      expect(restored.closeTotalAmount, 2500.0);
      expect(restored.notes, 'Morning shift');
      expect(restored.closeNotes, 'Evening shift');
    });

    test(
      'serializes and deserializes closeNotesMap and closeCoinsMap with computed total',
      () {
        const original = QaRegisterInput(
          openingFloatAmount: 1500.0,
          closeNotesMap: <int, int>{500: 3, 100: 2}, // 1500 + 200 = 1700
          closeCoinsMap: <int, int>{10: 5, 2: 10}, // 50 + 20 = 70 => total 1770
          notes: 'Morning shift',
          closeNotes: 'Evening shift',
        );
        final json = original.toJson();
        final restored = QaRegisterInput.fromJson(json);
        expect(restored.closeNotesMap[500], 3);
        expect(restored.closeNotesMap[100], 2);
        expect(restored.closeCoinsMap[10], 5);
        expect(restored.closeCoinsMap[2], 10);
        expect(restored.closeTotalAmount, 1770.0);
      },
    );

    test('verifies supportedDenominations, hasCoins, and hasNotes rules', () {
      expect(QaRegisterInput.supportedDenominations.contains(2000), isFalse);
      expect(QaRegisterInput.supportedDenominations.first, 500);
      expect(QaRegisterInput.hasCoins(500), isFalse);
      expect(QaRegisterInput.hasCoins(200), isFalse);
      expect(QaRegisterInput.hasCoins(100), isFalse);
      expect(QaRegisterInput.hasCoins(50), isFalse);
      expect(QaRegisterInput.hasCoins(20), isTrue);
      expect(QaRegisterInput.hasCoins(10), isTrue);
      expect(QaRegisterInput.hasCoins(5), isTrue);
      expect(QaRegisterInput.hasCoins(2), isTrue);
      expect(QaRegisterInput.hasCoins(1), isTrue);

      expect(QaRegisterInput.hasNotes(500), isTrue);
      expect(QaRegisterInput.hasNotes(200), isTrue);
      expect(QaRegisterInput.hasNotes(100), isTrue);
      expect(QaRegisterInput.hasNotes(50), isTrue);
      expect(QaRegisterInput.hasNotes(20), isTrue);
      expect(QaRegisterInput.hasNotes(10), isTrue);
      expect(QaRegisterInput.hasNotes(5), isTrue);
      expect(QaRegisterInput.hasNotes(2), isFalse);
      expect(QaRegisterInput.hasNotes(1), isFalse);
    });

    test('computeTotalFromBreakdown calculates accurate sum of all fields', () {
      final total = QaRegisterInput.computeTotalFromBreakdown(
        <int, int>{500: 4, 200: 2, 100: 5}, // 2000 + 400 + 500 = 2900
        <int, int>{20: 2, 5: 4}, // 40 + 20 = 60
      );
      expect(total, 2960);
    });

    test('copyWith updates specified fields only', () {
      const original = QaRegisterInput(
        openingFloatAmount: 1000.0,
        closeTotalAmount: 2000.0,
        closeNotesMap: <int, int>{500: 4},
        closeCoinsMap: <int, int>{10: 5},
        notes: 'Open notes',
        closeNotes: 'Close notes',
      );
      final updated = original.copyWith(
        closeTotalAmount: 3000.0,
        closeNotes: 'New close notes',
      );
      expect(updated.openingFloatAmount, 1000.0);
      expect(updated.notes, 'Open notes');
      expect(updated.closeTotalAmount, 3000.0);
      expect(updated.closeNotesMap[500], 4);
      expect(updated.closeCoinsMap[10], 5);
      expect(updated.closeNotes, 'New close notes');
    });
  });

  group('SharedPreferencesQaRegisterInputRepository', () {
    test('writes and reads profile-scoped register input', () async {
      final repo = SharedPreferencesQaRegisterInputRepository();
      const profileId = 'kpn-dev';

      // Default before write
      final initial = await repo.read(profileId);
      expect(initial.openingFloatAmount, 0.0);

      // Save input
      const custom = QaRegisterInput(
        openingFloatAmount: 3000.0,
        notes: 'Pre-seeded drawer',
      );
      await repo.write(profileId, custom);

      final readBack = await repo.read(profileId);
      expect(readBack.openingFloatAmount, 3000.0);
      expect(readBack.notes, 'Pre-seeded drawer');
    });
  });
}
