import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/order/cash_round_off.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_runner.dart';

void main() {
  group('Cash Round-Off Utility Tests', () {
    test(
      'calculateRoundOff rounds amounts correctly per POS business rules',
      () {
        expect(calculateRoundOff(100.40), equals(100));
        expect(calculateRoundOff(100.50), equals(101));
        expect(calculateRoundOff(100.75), equals(101));
        expect(calculateRoundOff(50.00), equals(50));
        expect(calculateRoundOff(99.49), equals(99));
      },
    );

    test(
      'PenguinPosOrderRunner.calculateRoundOff static forwarder matches utility',
      () {
        expect(PenguinPosOrderRunner.calculateRoundOff(100.40), equals(100));
        expect(PenguinPosOrderRunner.calculateRoundOff(100.50), equals(101));
        expect(PenguinPosOrderRunner.calculateRoundOff(75.25), equals(75));
      },
    );
  });
}
