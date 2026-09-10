import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/suites/order_suite_scenarios.dart';

/// A prerequisite that must be satisfied before a scenario can be executed.
///
/// These are descriptive requirements only. They never contain credential or
/// test-data values, which continue to be supplied through the configured QA
/// profile and execution flow.
enum QaTestRequirement {
  approvedNonProductionProfile,
  savedLoginCredentials,
  authenticatedSession,
  configuredTestItems,
}

/// Environment eligibility for a suite. Specific profile availability is
/// resolved at runtime from the user's configured profiles.
enum QaEnvironmentPolicy { approvedNonProductionOnly }

/// Represents a scenario within a test suite.
class TestSuiteScenario {
  const TestSuiteScenario({
    required this.id,
    required this.name,
    required this.tags,
    required this.stepsDescription,
    required this.purpose,
    required this.preconditions,
    required this.expectedOutcomes,
    this.requirements = const <QaTestRequirement>[],
    this.searchAliases = const <String>[],
  });

  final String id;
  final String name;
  final List<String> tags;
  final List<String> stepsDescription;
  final String purpose;
  final List<String> preconditions;
  final List<String> expectedOutcomes;
  final List<QaTestRequirement> requirements;
  final List<String> searchAliases;
}

/// Represents a test suite selectable from the sidebar.
class TestSuiteItem {
  const TestSuiteItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.scenarios,
    this.isImplemented = true,
    this.feature = '',
    this.purpose = '',
    this.searchAliases = const <String>[],
    this.environmentPolicy = QaEnvironmentPolicy.approvedNonProductionOnly,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<TestSuiteScenario> scenarios;
  final bool isImplemented;
  final String feature;
  final String purpose;
  final List<String> searchAliases;
  final QaEnvironmentPolicy environmentPolicy;

  static const List<TestSuiteItem> availableSuites = <TestSuiteItem>[
    TestSuiteItem(
      id: 'login_terminal',
      title: 'Login & Terminal',
      description:
          'Validates empty credential inputs, invalid credential handling, valid login flow, terminal selection, and home screen navigation.',
      icon: Icons.login_rounded,
      isImplemented: true,
      feature: 'Login & Terminal',
      purpose:
          'Verify that the login journey handles validation and authentication safely, then reaches a ready home screen after terminal selection.',
      searchAliases: <String>[
        'login',
        'authentication',
        'terminal',
        'sign in',
        'home screen',
      ],
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'empty_credentials',
          name: 'Login Validation',
          tags: <String>['validation', 'login'],
          stepsDescription: <String>[
            'Launch PenguinPOS',
            'Leave Login ID and Password blank',
            'Tap Login button',
            'Verify field validation error toast is displayed',
          ],
          purpose: 'Confirm required Login ID and Password validation.',
          preconditions: <String>['PenguinPOS is on the login screen.'],
          expectedOutcomes: <String>[
            'A field validation error is shown.',
            'The user remains on the login screen.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
          ],
          searchAliases: <String>['blank login', 'empty password'],
        ),
        TestSuiteScenario(
          id: 'invalid_credentials',
          name: 'Auth Failure Handling',
          tags: <String>['security', 'login'],
          stepsDescription: <String>[
            'Enter non-existent Login ID (0000000000)',
            'Enter arbitrary password',
            'Tap Login button',
            'Verify server unauthorized / invalid credential alert',
          ],
          purpose: 'Confirm invalid credentials are rejected safely.',
          preconditions: <String>['PenguinPOS is on the login screen.'],
          expectedOutcomes: <String>[
            'An unauthorized or invalid-credential alert is shown.',
            'The user remains unauthenticated.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
          ],
          searchAliases: <String>[
            'invalid login',
            'authentication failure',
            'unauthorized',
          ],
        ),
        TestSuiteScenario(
          id: 'valid_login',
          name: 'Valid Login Flow',
          tags: <String>['smoke', 'critical_path'],
          stepsDescription: <String>[
            'Enter valid 10-digit Login ID',
            'Enter valid Test Password',
            'Tap Login button',
            'Wait for Terminal Selection screen (login.terminal.continue)',
            'Tap Continue on selected Terminal',
            'Assert Home Screen (home.screen) is active and ready',
          ],
          purpose:
              'Verify a saved QA login can select a terminal and reach a ready home screen.',
          preconditions: <String>[
            'PenguinPOS is on the login screen.',
            'A selectable terminal is available for the QA profile.',
          ],
          expectedOutcomes: <String>[
            'Terminal selection is shown after successful authentication.',
            'The selected terminal continues to an active home screen.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.savedLoginCredentials,
          ],
          searchAliases: <String>[
            'valid login',
            'terminal selection',
            'login flow',
          ],
        ),
      ],
    ),
    TestSuiteItem(
      id: 'order_checkout',
      title: 'Order & Cash Payment',
      description:
          'Executes complete end-to-end POS order creation, SKU scanning, weighed item entry, cart update, cash payment round-off, and order success wrap-up.',
      icon: Icons.shopping_cart_checkout_rounded,
      isImplemented: true,
      feature: 'Order & Cash Payment',
      purpose:
          'Verify an authenticated cashier can build a sale, enter regular or weighed items, and complete a rounded cash payment.',
      searchAliases: <String>[
        'order',
        'sale',
        'checkout',
        'cash',
        'payment',
        'sku',
        'weighed item',
        'cart',
      ],
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'order_session_check',
          name: OrderSuiteScenarios.session,
          tags: <String>['session', 'auth', 'terminal'],
          stepsDescription: <String>[
            'Verify active POS session state via waitForAnyKey',
            'If Login Screen (login.id) is present, submit cashier credentials',
            'If Idle Lock screen is active, enter 4-digit PIN on numpad',
            'Confirm terminal selection and transition to main Home screen',
          ],
          purpose:
              'Establish an authenticated session and ensure terminal readiness.',
          preconditions: <String>[
            'PenguinPOS app is launched and reachable via driver.',
          ],
          expectedOutcomes: <String>[
            'The main POS Home screen is active and ready for sale entry.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
          ],
          searchAliases: <String>['session', 'auth', 'terminal', 'idle pin'],
        ),
        TestSuiteScenario(
          id: 'order_start_sale',
          name: OrderSuiteScenarios.startSale,
          tags: <String>['sale', 'customer', 'order'],
          stepsDescription: <String>[
            'Navigate to Order screen (home.tab.order)',
            'Verify Start Sale widget (order.sale.start) is visible',
            'Tap Continue Without Customer (sale.continuewithoutcustomer)',
            'Confirm Order Table (order.table) and NumPad section are displayed',
          ],
          purpose:
              'Initiate order transaction and proceed with customer proxy handling.',
          preconditions: <String>[
            'An authenticated session is ready at the home screen.',
          ],
          expectedOutcomes: <String>[
            'The order table and number-pad controls are active for cart editing.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
          ],
          searchAliases: <String>['start sale', 'customer', 'order screen'],
        ),
        TestSuiteScenario(
          id: 'order_sku_scan',
          name: OrderSuiteScenarios.standardSku,
          tags: <String>['sku', 'barcode', 'cart'],
          stepsDescription: <String>[
            'Focus SKU input code field (order.numpad.input.code)',
            'Enter standard SKU / barcode digits via numpad (order.numpad.digit.<0-9>)',
            'Tap Enter (order.numpad.enter) to submit item into cart',
            'Verify item is added to line-item list with correct unit pricing',
          ],
          purpose:
              'Verify regular SKU scanning and cart line-item synchronization.',
          preconditions: <String>[
            'An active order session is on the cart screen.',
            'Configured SKU items are available for the selected profile.',
          ],
          expectedOutcomes: <String>[
            'Each standard SKU item is accepted into the order table.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>['scan sku', 'barcode', 'add item', 'cart'],
        ),
        TestSuiteScenario(
          id: 'order_weighed_entry',
          name: OrderSuiteScenarios.weighedItem,
          tags: <String>['weighed', 'weight', 'scale'],
          stepsDescription: <String>[
            'Enter weighed item SKU code in numpad input',
            'Verify input mode automatically prompts for weight (order.numpad.input.weight)',
            'Input weight amount in kg and submit via Enter',
            'Confirm weighed line-item calculation based on weight × unit price',
          ],
          purpose:
              'Verify weighed item capture, scale tare prompts, and price calculation.',
          preconditions: <String>[
            'Cart is open and weighed SKU items are configured.',
          ],
          expectedOutcomes: <String>[
            'Weighed items request weight input and compute correct line total.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>['weighed', 'weight', 'scale', 'tare'],
        ),
        TestSuiteScenario(
          id: 'order_cart_review',
          name: OrderSuiteScenarios.cartReview,
          tags: <String>['cart', 'summary', 'checkout'],
          stepsDescription: <String>[
            'Tap Update Cart (order.update_cart) to trigger backend price sync',
            'Wait until Proceed To Pay button (order.proceed_to_pay) is active',
            'Tap Proceed To Pay to transition to Payment Screen (payment.screen)',
            'Verify Total Payable amount on Bill Summary (bill_summary.total_payable)',
          ],
          purpose:
              'Synchronize cart state and transition into payment method selection.',
          preconditions: <String>[
            'At least one SKU item has been added to the cart.',
          ],
          expectedOutcomes: <String>[
            'The payment screen is displayed with total payable and tax breakdown.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>[
            'cart update',
            'proceed to pay',
            'bill summary',
          ],
        ),
        TestSuiteScenario(
          id: 'order_cash_checkout',
          name: OrderSuiteScenarios.cashCheckout,
          tags: <String>['payment', 'cash', 'round_off', 'success'],
          stepsDescription: <String>[
            'Select Cash Payment method (payment.cash)',
            'Read exact payable total and compute POS round-off cash tender',
            'Enter cash tender digits via numpad (payment.numpad.digit.<0-9>)',
            'Tap Place Order (payment.place_order) to submit transaction',
            'Verify Order Success Screen (order.success.screen) and complete summary',
          ],
          purpose:
              'Verify cash round-off tender, transaction placement, and receipt generation.',
          preconditions: <String>[
            'Payment screen is active with valid payable amount.',
          ],
          expectedOutcomes: <String>[
            'Cash payment is accepted and order success screen is confirmed.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>[
            'cash payment',
            'round off',
            'place order',
            'order success',
          ],
        ),
      ],
    ),
    TestSuiteItem(
      id: 'register',
      title: 'Open Register',
      description:
          'Automates cash register opening, initial float cash submission (₹0–₹5,000), and POS state verification.',
      icon: Icons.point_of_sale_rounded,
      isImplemented: true,
      feature: 'Register Management',
      purpose:
          'Verify opening the cash register with a configured opening float cash amount and transitioning cleanly to the order table.',
      searchAliases: <String>[
        'register',
        'open register',
        'float',
        'drawer',
        'opening float',
      ],
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'open_register',
          name: 'Open Register Flow',
          tags: <String>['register', 'float', 'drawer'],
          stepsDescription: <String>[
            'Launch PenguinPOS and verify authentication',
            'Probe UI state; navigate to Register via order button or home tab',
            'Enter configured opening float amount in cash input field',
            'Tap Open Register submit button',
            'Verify transition back to Order Screen with active register session',
          ],
          purpose:
              'Confirm cash drawer opening float submission and POS state transition.',
          preconditions: <String>[
            'PenguinPOS is logged in and terminal selected.',
            'Cash register is currently closed.',
          ],
          expectedOutcomes: <String>[
            'Opening float cash is accepted without validation error.',
            'Register state transitions to open in PenguinPOS.',
            'Active view returns to the Order Table ready for transactions.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
          ],
          searchAliases: <String>[
            'open register',
            'opening float',
            'drawer open',
          ],
        ),
      ],
    ),
    TestSuiteItem(
      id: 'close_register',
      title: 'Close Register',
      description:
          'Automates cash register closing with target total cash amount, payment modes verification, and denominations distribution.',
      icon: Icons.point_of_sale_outlined,
      isImplemented: true,
      feature: 'Register Management',
      purpose:
          'Verify closing the cash register with a configured total amount, ensuring all payment summary fields and denomination counts are filled and submitted cleanly.',
      searchAliases: <String>[
        'close register',
        'register close',
        'reconciliation',
        'cash closing',
        'total amount',
      ],
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'close_register_flow',
          name: 'Close Register Flow',
          tags: <String>['register', 'close', 'cash', 'denominations'],
          stepsDescription: <String>[
            'Verify register screen is active (or navigate via home tab)',
            'Check and fill Closing Float Cash if present',
            'Check and fill payment gateway fields (PineLabs Card/UPI, RazorPay, Paytm, etc.) if present',
            'Distribute configured Total Cash Amount across Note and Coin denominations',
            'Verify calculated Total Cash display matches expected total',
            'Tap Close Register submit button',
            'Confirm register closed successfully',
          ],
          purpose:
              'Confirm cash drawer closing submission with all required denominations and payment gateway fields filled.',
          preconditions: <String>[
            'PenguinPOS is logged in and terminal selected.',
            'Cash register is currently open.',
          ],
          expectedOutcomes: <String>[
            'Payment summary gateway fields (amount & count) are filled.',
            'Cash denominations match configured total cash amount.',
            'Close Register button enables and successfully submits.',
            'Register state transitions to closed.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
          ],
          searchAliases: <String>[
            'close register',
            'cash reconciliation',
            'drawer close',
          ],
        ),
      ],
    ),
    // TestSuiteItem(
    //   id: 'api_regression',
    //   title: 'API Regression',
    //   description: 'Executes automated API integration & endpoint contract validation suites.',
    //   icon: Icons.alt_route_rounded,
    //   isImplemented: false,
    //   scenarios: <TestSuiteScenario>[],
    // ),
    // TestSuiteItem(
    //   id: 'e2e_smoke',
    //   title: 'E2E Smoke Tests',
    //   description: 'Executes end-to-end multi-terminal POS smoke test workflows.',
    //   icon: Icons.speed_rounded,
    //   isImplemented: false,
    //   scenarios: <TestSuiteScenario>[],
    // ),
  ];
}
