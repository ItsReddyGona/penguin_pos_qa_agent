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

    test('copyWith updates specified fields only', () {
      const original = QaRegisterInput(
        openingFloatAmount: 1000.0,
        closeTotalAmount: 2000.0,
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
