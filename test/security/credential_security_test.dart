import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/automation/login/login_scenario.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/core/secret_redactor.dart';

void main() {
  const loginId = '9000000001';
  const password = 'qa-password-should-not-appear';
  const pin = '4829';

  test('scenario exports exclude all runtime credentials', () {
    const order = OrderScenario(
      id: 'safe-export',
      name: 'Safe export',
      loginId: loginId,
      password: password,
      unlockPin: pin,
      items: <OrderItem>[OrderItem(skuCode: '22')],
    );
    const login = LoginScenario(
      id: 'safe-login-export',
      name: 'Safe login export',
      loginId: loginId,
      password: password,
      unlockPin: pin,
    );

    final orderJson = jsonEncode(order.toJson());
    final loginJson = jsonEncode(login.toJson());
    for (final secret in <String>[loginId, password, pin]) {
      expect(orderJson, isNot(contains(secret)));
      expect(loginJson, isNot(contains(secret)));
    }
  });

  test('redacts credentials from a user-visible error', () {
    final redacted = redactSecrets(
      'Login $loginId failed with password $password and PIN $pin.',
      const <String?>[loginId, password, pin],
    );

    expect(redacted, isNot(contains(loginId)));
    expect(redacted, isNot(contains(password)));
    expect(redacted, isNot(contains(pin)));
    expect(redacted, contains('[REDACTED]'));
  });
}
