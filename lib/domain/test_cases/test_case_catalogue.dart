import 'package:penguin_pos_qa_agent/domain/test_cases/test_case_definition.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/test_input_schema.dart';

/// The runner-owned catalogue of portable test case contracts.
///
/// Interfaces may render these definitions, but do not define their own input
/// contract. This prevents manual, AI, CLI, and MCP surfaces from drifting.
class TestCaseCatalogue {
  TestCaseCatalogue(Iterable<TestCaseDefinition> definitions)
    : definitions = List<TestCaseDefinition>.unmodifiable(definitions);

  static final TestCaseCatalogue builtIn = TestCaseCatalogue(
    <TestCaseDefinition>[loginTerminal, orderCashCheckout],
  );

  final List<TestCaseDefinition> definitions;

  TestCaseDefinition? findById(String id) {
    for (final definition in definitions) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static const TestCaseDefinition loginTerminal = TestCaseDefinition(
    id: 'login_terminal',
    name: 'Login & Terminal',
    description: 'Validates the configured QA login and terminal flow.',
    category: 'login',
    tags: <String>['smoke', 'login', 'terminal'],
    preconditions: <String>['A non-production QA profile is selected.'],
    expectedOutcomes: <String>['The POS home screen is ready.'],
    runnerTemplateId: 'login_terminal',
    inputSchema: TestInputSchema(fields: <TestInputField>[]),
    isBuiltIn: true,
  );

  static const TestCaseDefinition orderCashCheckout = TestCaseDefinition(
    id: 'order_checkout',
    name: 'Order & Cash Payment',
    description: 'Creates configured orders and completes cash checkout.',
    category: 'order',
    tags: <String>['smoke', 'order', 'cash'],
    preconditions: <String>['A non-production QA profile is selected.'],
    expectedOutcomes: <String>['Every configured order completes.'],
    runnerTemplateId: 'order_checkout',
    inputSchema: TestInputSchema(
      fields: <TestInputField>[
        TestInputField(
          path: 'ordersCount',
          label: 'Order count',
          type: TestInputFieldType.integer,
          required: true,
          defaultValue: 1,
          validation: TestInputValidation(minimum: 1, maximum: 50),
        ),
        TestInputField(
          path: 'itemStrategy',
          label: 'Item strategy',
          type: TestInputFieldType.singleSelect,
          defaultValue: 'sameForAll',
          choices: <TestInputChoice>[
            TestInputChoice(value: 'sameForAll', label: 'Same for all orders'),
            TestInputChoice(value: 'perOrder', label: 'Per order'),
          ],
        ),
        TestInputField(
          path: 'items',
          label: 'Items',
          type: TestInputFieldType.list,
          required: true,
          visibleWhen: <String, Object?>{'itemStrategy': 'sameForAll'},
          validation: TestInputValidation(minimumItems: 1),
          itemSchema: _orderItemSchema,
        ),
        TestInputField(
          path: 'perOrderItems',
          label: 'Items by order',
          type: TestInputFieldType.list,
          required: true,
          visibleWhen: <String, Object?>{'itemStrategy': 'perOrder'},
          validation: TestInputValidation(minimumItems: 1),
          itemSchema: _perOrderItemSchema,
        ),
      ],
    ),
    isBuiltIn: true,
  );

  static const TestInputSchema _orderItemSchema = TestInputSchema(
    fields: <TestInputField>[
      TestInputField(
        path: 'skuCode',
        label: 'SKU code',
        type: TestInputFieldType.text,
        required: true,
        validation: TestInputValidation(pattern: r'\S+'),
      ),
      TestInputField(
        path: 'quantity',
        label: 'Quantity',
        type: TestInputFieldType.integer,
        required: true,
        defaultValue: 1,
        validation: TestInputValidation(minimum: 1),
      ),
      TestInputField(
        path: 'type',
        label: 'Item type',
        type: TestInputFieldType.singleSelect,
        defaultValue: 'nonWeighed',
        choices: <TestInputChoice>[
          TestInputChoice(value: 'nonWeighed', label: 'Non-weighed'),
          TestInputChoice(value: 'weighed', label: 'Weighed'),
          TestInputChoice(value: 'bizerba', label: 'Bizerba'),
        ],
      ),
      TestInputField(
        path: 'weight',
        label: 'Weight',
        type: TestInputFieldType.decimal,
        required: true,
        visibleWhen: <String, Object?>{'type': 'weighed'},
        validation: TestInputValidation(minimum: 0.001),
      ),
      TestInputField(
        path: 'entryMode',
        label: 'Entry mode',
        type: TestInputFieldType.singleSelect,
        defaultValue: 'scan',
        choices: <TestInputChoice>[
          TestInputChoice(value: 'scan', label: 'Scan'),
          TestInputChoice(value: 'manualNumpad', label: 'Manual numpad'),
          TestInputChoice(value: 'manualQwerty', label: 'Manual keyboard'),
        ],
      ),
    ],
  );

  static const TestInputSchema _perOrderItemSchema = TestInputSchema(
    fields: <TestInputField>[
      TestInputField(
        path: 'order',
        label: 'Order number',
        type: TestInputFieldType.integer,
        required: true,
        validation: TestInputValidation(minimum: 1),
      ),
      TestInputField(
        path: 'items',
        label: 'Items',
        type: TestInputFieldType.list,
        required: true,
        validation: TestInputValidation(minimumItems: 1),
        itemSchema: _orderItemSchema,
      ),
    ],
  );
}
