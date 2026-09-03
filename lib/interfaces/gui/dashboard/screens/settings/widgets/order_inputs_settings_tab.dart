import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/order_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/order_config_tab.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/sku_item_row.dart';

typedef OrderInputsLoader = Future<List<OrderItem>> Function(String profileId);
typedef OrderInputsSaver =
    Future<void> Function(String profileId, List<OrderItem> items);
typedef OrderCasesLoader =
    Future<List<OrderTestCaseDefinition>> Function(String profileId);
typedef OrderCasesSaver =
    Future<void> Function(
      String profileId,
      List<OrderTestCaseDefinition> cases,
    );

class OrderInputsSettingsTab extends StatefulWidget {
  const OrderInputsSettingsTab({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.loadItems,
    required this.saveItems,
    this.loadCases,
    this.saveCases,
    required this.onProfileChanged,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final OrderInputsLoader loadItems;
  final OrderInputsSaver saveItems;
  final OrderCasesLoader? loadCases;
  final OrderCasesSaver? saveCases;
  final ValueChanged<QaProfile> onProfileChanged;

  @override
  State<OrderInputsSettingsTab> createState() => _OrderInputsSettingsTabState();
}

class _OrderInputsSettingsTabState extends State<OrderInputsSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  List<OrderItem> _items = <OrderItem>[];
  final List<SkuRowControllers> _rowControllers = <SkuRowControllers>[];
  final Map<int, List<OrderItem>> _perIterationItems = <int, List<OrderItem>>{};
  final Map<int, List<SkuRowControllers>> _perIterationControllers =
      <int, List<SkuRowControllers>>{};

  OrderTestCaseDefinition? _testCase;
  int _ordersCount = 1;
  int _selectedIterationIndex = 1;
  UiCustomMode _uiCustomMode = UiCustomMode.common;

  final _idController = TextEditingController(text: 'ORD-001');
  final _titleController = TextEditingController(text: 'Cash Order');
  final _descriptionController = TextEditingController();
  final _loginCaseController = TextEditingController(text: 'valid_login');
  final _ordersCountController = TextEditingController(text: '1');

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OrderInputsSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfile.id != widget.selectedProfile.id) _load();
  }

  @override
  void dispose() {
    for (final ctrl in _rowControllers) {
      ctrl.dispose();
    }
    for (final list in _perIterationControllers.values) {
      for (final ctrl in list) {
        ctrl.dispose();
      }
    }
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _loginCaseController.dispose();
    _ordersCountController.dispose();
    super.dispose();
  }

  void _syncControllersWithItems() {
    while (_rowControllers.length < _items.length) {
      final item = _items[_rowControllers.length];
      _rowControllers.add(
        SkuRowControllers(skuCode: item.skuCode, weight: item.weight),
      );
    }
    while (_rowControllers.length > _items.length) {
      _rowControllers.removeLast().dispose();
    }
    for (var i = 0; i < _items.length; i++) {
      if (_rowControllers[i].skuCodeController.text != _items[i].skuCode) {
        _rowControllers[i].skuCodeController.text = _items[i].skuCode;
      }
      final weightText = _items[i].weight != null
          ? _items[i].weight.toString()
          : '';
      if (_rowControllers[i].weightController.text != weightText) {
        _rowControllers[i].weightController.text = weightText;
      }
    }
  }

  void _syncPerIterationControllers(int iterNumber) {
    final list = _perIterationItems[iterNumber] ?? <OrderItem>[];
    final controllers = _perIterationControllers.putIfAbsent(
      iterNumber,
      () => <SkuRowControllers>[],
    );
    while (controllers.length < list.length) {
      final item = list[controllers.length];
      controllers.add(
        SkuRowControllers(skuCode: item.skuCode, weight: item.weight),
      );
    }
    while (controllers.length > list.length) {
      controllers.removeLast().dispose();
    }
    for (var i = 0; i < list.length; i++) {
      if (controllers[i].skuCodeController.text != list[i].skuCode) {
        controllers[i].skuCodeController.text = list[i].skuCode;
      }
      final weightText = list[i].weight != null
          ? list[i].weight.toString()
          : '';
      if (controllers[i].weightController.text != weightText) {
        controllers[i].weightController.text = weightText;
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.loadItems(widget.selectedProfile.id);
    final cases = widget.loadCases == null
        ? const <OrderTestCaseDefinition>[]
        : await widget.loadCases!(widget.selectedProfile.id);
    if (mounted) {
      setState(() {
        _items = List<OrderItem>.from(items);
        if (cases.isNotEmpty) {
          _testCase = cases.first;
          _idController.text = _testCase!.id;
          _titleController.text = _testCase!.title;
          _descriptionController.text = _testCase!.description;
          _loginCaseController.text = _testCase!.loginTestCaseId;
          _ordersCount = _testCase!.orderCount;
          _ordersCountController.text = _ordersCount.toString();
          _uiCustomMode = _testCase!.uiCustomMode;
          _perIterationItems
            ..clear()
            ..addAll(
              _testCase!.perIterationItems.map(
                (key, value) => MapEntry(key, List<OrderItem>.from(value)),
              ),
            );
          if (_items.isEmpty) _items = List<OrderItem>.from(_testCase!.items);
        }
        if (_items.isEmpty) {
          _items = <OrderItem>[OrderItem.draft()];
        }
        _syncControllersWithItems();
        if (_uiCustomMode == UiCustomMode.perIteration) {
          for (final iteration in _perIterationItems.keys) {
            _syncPerIterationControllers(iteration);
          }
        }
        _loading = false;
      });
    }
  }

  void _addItem() {
    setState(() {
      _items.add(OrderItem.draft());
      _rowControllers.add(SkuRowControllers(skuCode: ''));
    });
  }

  List<OrderItem> _itemsForIteration(int iterNumber) {
    return _perIterationItems.putIfAbsent(
      iterNumber,
      () => iterNumber == 1
          ? List<OrderItem>.from(_items)
          : <OrderItem>[OrderItem.draft()],
    );
  }

  void _addPerIterationItem(int iterNumber) {
    setState(() {
      final currentList = _itemsForIteration(iterNumber);
      currentList.add(OrderItem.draft());
      _syncPerIterationControllers(iterNumber);
    });
  }

  void _removePerIterationItem(int iterNumber, int index) {
    setState(() {
      final currentList = _itemsForIteration(iterNumber);
      if (currentList.length > 1) {
        currentList.removeAt(index);
      } else {
        currentList[0] = OrderItem.draft();
      }
      _syncPerIterationControllers(iterNumber);
    });
  }

  void _removeItem(int index) {
    setState(() {
      if (_items.length > 1) {
        _items.removeAt(index);
        _rowControllers.removeAt(index).dispose();
      } else {
        _items[0] = OrderItem.draft();
        _rowControllers[0].skuCodeController.clear();
        _rowControllers[0].weightController.clear();
      }
    });
  }

  void _updateItem(int index, OrderItem updated) {
    setState(() {
      _items[index] = updated;
      _perIterationItems[1] = List<OrderItem>.from(_items);
      if (_rowControllers[index].skuCodeController.text != updated.skuCode) {
        _rowControllers[index].skuCodeController.text = updated.skuCode;
      }
      final weightText = updated.weight != null
          ? updated.weight.toString()
          : '';
      if (_rowControllers[index].weightController.text != weightText) {
        _rowControllers[index].weightController.text = weightText;
      }
    });
  }

  void _updatePerIterationItem(
    int iterNumber,
    int index,
    OrderItem updatedItem,
  ) {
    setState(() {
      final currentList = _itemsForIteration(iterNumber);
      currentList[index] = updatedItem;
      if (iterNumber == 1) {
        if (index < _items.length) {
          _items[index] = updatedItem;
        }
      }
      _syncPerIterationControllers(iterNumber);
    });
  }

  void _cloneAndAddOrder(int sourceIter) {
    final sourceList = _uiCustomMode == UiCustomMode.common || sourceIter == 1
        ? (_perIterationItems[sourceIter] ?? List<OrderItem>.from(_items))
        : (_perIterationItems[sourceIter] ?? <OrderItem>[OrderItem.draft()]);

    final newCount = _ordersCount + 1;
    final newOrderNumber = newCount;

    setState(() {
      _uiCustomMode = UiCustomMode.perIteration;
      _ordersCount = newCount;
      _ordersCountController.text = newCount.toString();

      if (!_perIterationItems.containsKey(1)) {
        _perIterationItems[1] = _items
            .map(
              (item) => OrderItem.draft(
                skuCode: item.skuCode,
                type: item.type,
                weight: item.weight,
                weightInputMode: item.weightInputMode,
                entryMode: item.entryMode,
              ),
            )
            .toList();
      }

      _perIterationItems[newOrderNumber] = sourceList
          .map(
            (item) => OrderItem.draft(
              skuCode: item.skuCode,
              type: item.type,
              weight: item.weight,
              weightInputMode: item.weightInputMode,
              entryMode: item.entryMode,
            ),
          )
          .toList();

      _selectedIterationIndex = newOrderNumber;
      _syncPerIterationControllers(newOrderNumber);
    });
  }

  void _removeOrderIteration(int iterNumber) {
    if (_ordersCount <= 1) return;
    setState(() {
      for (int i = iterNumber; i < _ordersCount; i++) {
        _perIterationItems[i] =
            _perIterationItems[i + 1] ?? <OrderItem>[OrderItem.draft()];
      }
      _perIterationItems.remove(_ordersCount);
      final controllers = _perIterationControllers.remove(_ordersCount);
      if (controllers != null) {
        for (final ctrl in controllers) {
          ctrl.dispose();
        }
      }
      _ordersCount--;
      if (_ordersCount <= 1) {
        _uiCustomMode = UiCustomMode.common;
        _perIterationItems[1] = List<OrderItem>.from(_items);
      }
      _ordersCountController.text = _ordersCount.toString();
      if (_selectedIterationIndex > _ordersCount) {
        _selectedIterationIndex = _ordersCount;
      }
      _syncPerIterationControllers(_selectedIterationIndex);
    });
  }

  void _updateOrdersCount(int count) {
    final clamped = count.clamp(1, 50);
    setState(() {
      if (clamped < _ordersCount) {
        for (int i = clamped + 1; i <= _ordersCount; i++) {
          _perIterationItems.remove(i);
          final controllers = _perIterationControllers.remove(i);
          if (controllers != null) {
            for (final ctrl in controllers) {
              ctrl.dispose();
            }
          }
        }
      }
      _ordersCount = clamped;
      if (clamped <= 1) {
        _uiCustomMode = UiCustomMode.common;
        _perIterationItems[1] = List<OrderItem>.from(_items);
      }
      _ordersCountController.text = clamped.toString();
      if (_selectedIterationIndex > clamped) {
        _selectedIterationIndex = clamped;
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_ordersCount <= 1) {
        _uiCustomMode = UiCustomMode.common;
        _perIterationItems[1] = List<OrderItem>.from(_items);
      }
      await widget.saveItems(widget.selectedProfile.id, _items);
      if (widget.saveCases != null) {
        final testCase = OrderTestCaseDefinition(
          id: _idController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          loginTestCaseId: _loginCaseController.text.trim(),
          orderCount: _ordersCount,
          items: List<OrderItem>.unmodifiable(_items),
          uiCustomMode: _ordersCount <= 1 ? UiCustomMode.common : _uiCustomMode,
          perIterationItems: _perIterationItems.map(
            (key, value) => MapEntry(key, List<OrderItem>.unmodifiable(value)),
          ),
        );
        await widget.saveCases!(
          widget.selectedProfile.id,
          <OrderTestCaseDefinition>[testCase],
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved order configuration & ${_items.length} SKU item${_items.length == 1 ? '' : 's'} for ${widget.selectedProfile.label}.',
            ),
            backgroundColor: const Color(0xFF658A7A),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save order inputs: $error'),
            backgroundColor: const Color(0xFF9A4D45),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isCustomPerIter =
        _ordersCount > 1 && _uiCustomMode == UiCustomMode.perIteration;
    final currentIterList = isCustomPerIter
        ? _itemsForIteration(_selectedIterationIndex)
        : _items;

    if (isCustomPerIter) {
      _syncPerIterationControllers(_selectedIterationIndex);
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Order SKU Inputs & Parameters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C302E),
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('save-order-inputs'),
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF658A7A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Order Inputs'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure the default SKU items and test parameters loaded by the Order & Cash Payment test suite.',
            style: TextStyle(fontSize: 13, color: Color(0xFF787A76)),
          ),
          const SizedBox(height: 16),

          // 1. Order Test Case Metadata Card (with integrated Order Count stepper at top)
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC7C9C4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5ECE8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Test Case Flow Config',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Color(0xFF2C302E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _idController,
                          decoration: _fieldDecoration(
                            label: 'Order Test Case ID',
                            hint: 'ORD-001',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'ID is required.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _titleController,
                          decoration: _fieldDecoration(
                            label: 'Title',
                            hint: 'Cash Order Flow',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Title is required.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Order Count Stepper right at top
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Orders Count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                Text(
                                  'Back-to-Back',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 18,
                              ),
                              onPressed: _saving || _ordersCount <= 1
                                  ? null
                                  : () => _updateOrdersCount(_ordersCount - 1),
                            ),
                            SizedBox(
                              width: 36,
                              child: TextField(
                                controller: _ordersCountController,
                                enabled: !_saving,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  final parsed = int.tryParse(val) ?? 1;
                                  _updateOrdersCount(parsed);
                                },
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 18,
                              ),
                              onPressed: _saving || _ordersCount >= 50
                                  ? null
                                  : () => _updateOrdersCount(_ordersCount + 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _descriptionController,
                          decoration: _fieldDecoration(
                            label: 'Description',
                            hint:
                                'End-to-end cash payment checkout with standard and weighed SKUs',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 240,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            TextFormField(
                              controller: _loginCaseController,
                              decoration: _fieldDecoration(
                                label: 'Login Test Case ID Reference',
                                hint: 'valid_login',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '🔑 Credentials inherited from Login tab',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Main Order SKU Items Card matching Image 1 Design
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFFC7C9C4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Mode Selection when Order Count > 1
                  if (_ordersCount > 1) ...<Widget>[
                    Row(
                      children: <Widget>[
                        ChoiceChip(
                          avatar: !isCustomPerIter
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                )
                              : null,
                          label: const Text('Common Payload (Same for All)'),
                          selected: !isCustomPerIter,
                          selectedColor: const Color(0xFFEFF6FF),
                          side: BorderSide(
                            color: !isCustomPerIter
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFCBD5E1),
                          ),
                          onSelected: _saving
                              ? null
                              : (val) {
                                  if (val) {
                                    setState(
                                      () => _uiCustomMode = UiCustomMode.common,
                                    );
                                  }
                                },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          avatar: isCustomPerIter
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                )
                              : null,
                          label: const Text('Custom Payload per Iteration'),
                          selected: isCustomPerIter,
                          selectedColor: const Color(0xFFEFF6FF),
                          side: BorderSide(
                            color: isCustomPerIter
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFCBD5E1),
                          ),
                          onSelected: _saving
                              ? null
                              : (val) {
                                  if (val) {
                                    setState(
                                      () => _uiCustomMode =
                                          UiCustomMode.perIteration,
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Order Iteration Tabs when in Custom Payload mode
                    if (isCustomPerIter) ...<Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            ...List<Widget>.generate(_ordersCount, (idx) {
                              final iterNum = idx + 1;
                              final isSel = _selectedIterationIndex == iterNum;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InputChip(
                                  label: Text('Order #$iterNum'),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF2563EB),
                                  labelStyle: TextStyle(
                                    color: isSel
                                        ? Colors.white
                                        : const Color(0xFF334155),
                                    fontWeight: isSel
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  deleteIcon: _ordersCount > 1
                                      ? Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: isSel
                                              ? Colors.white.withValues(
                                                  alpha: 0.8,
                                                )
                                              : const Color(0xFF94A3B8),
                                        )
                                      : null,
                                  onDeleted: _ordersCount > 1 && !_saving
                                      ? () => _removeOrderIteration(iterNum)
                                      : null,
                                  onSelected: (val) {
                                    setState(
                                      () => _selectedIterationIndex = iterNum,
                                    );
                                  },
                                ),
                              );
                            }),
                            IconButton(
                              tooltip: 'Add Blank Order (+1)',
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () {
                                      final newCount = _ordersCount + 1;
                                      _updateOrdersCount(newCount);
                                      setState(() {
                                        _selectedIterationIndex = newCount;
                                      });
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                  ],

                  // Common or Custom Test SKU Items Header
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.table_rows_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCustomPerIter
                            ? 'SKU Items for Order #$_selectedIterationIndex'
                            : 'Common Test SKU Items',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        key: const ValueKey<String>('clone-order-btn'),
                        onPressed: _saving
                            ? null
                            : () => _cloneAndAddOrder(
                                isCustomPerIter ? _selectedIterationIndex : 1,
                              ),
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: Text(
                          isCustomPerIter
                              ? 'Clone Order #$_selectedIterationIndex (+1)'
                              : 'Clone Order',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        key: const ValueKey<String>('add-order-sku'),
                        onPressed: _saving
                            ? null
                            : () => isCustomPerIter
                                  ? _addPerIterationItem(
                                      _selectedIterationIndex,
                                    )
                                  : _addItem(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add SKU Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // SkuItemRow horizontal list
                  ...currentIterList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final ctrls = isCustomPerIter
                        ? (_perIterationControllers[_selectedIterationIndex] !=
                                      null &&
                                  index <
                                      _perIterationControllers[_selectedIterationIndex]!
                                          .length
                              ? _perIterationControllers[_selectedIterationIndex]![index]
                              : null)
                        : (index < _rowControllers.length
                              ? _rowControllers[index]
                              : null);

                    return SkuItemRow(
                      key: ValueKey<String>(
                        isCustomPerIter
                            ? 'iter_${_selectedIterationIndex}_${item.rowId.isEmpty ? index : item.rowId}'
                            : 'order-input-sku-${item.rowId.isEmpty ? index : item.rowId}',
                      ),
                      index: index,
                      item: item,
                      skuCodeController: ctrls?.skuCodeController,
                      weightController: ctrls?.weightController,
                      running: _saving,
                      onUpdateItem: (updated) => isCustomPerIter
                          ? _updatePerIterationItem(
                              _selectedIterationIndex,
                              index,
                              updated,
                            )
                          : _updateItem(index, updated),
                      onRemoveItem: () => isCustomPerIter
                          ? _removePerIterationItem(
                              _selectedIterationIndex,
                              index,
                            )
                          : _removeItem(index),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  String? label,
  String? hint,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  suffixIcon: suffixIcon,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
);
