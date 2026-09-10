import 'dart:convert';

enum SkuItemType {
  nonWeighed('Non-Weighed SKU'),
  weighed('Weighed SKU'),
  bizerba('Bizerba Barcode');

  const SkuItemType(this.label);
  final String label;

  static SkuItemType fromString(String? val) {
    final normalized = val?.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    if (normalized == 'bizerba' || normalized == 'bizerbabarcode') {
      return SkuItemType.bizerba;
    }
    if (normalized == 'weighed' || normalized == 'weighedsku') {
      return SkuItemType.weighed;
    }
    return SkuItemType.nonWeighed;
  }
}

enum ItemEntryMode {
  scan('Scan (Default)'),
  manualNumpad('Manual Numpad'),
  manualQwerty('Manual QWERTY');

  const ItemEntryMode(this.label);
  final String label;

  static ItemEntryMode fromString(String? val) {
    final normalized = val?.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    if (normalized == 'manualqwerty' || normalized == 'qwerty') {
      return ItemEntryMode.manualQwerty;
    }
    if (normalized == 'manual' ||
        normalized == 'manualnumpad' ||
        normalized == 'numpad' ||
        normalized == 'manualentry' ||
        normalized == 'manualtext') {
      return ItemEntryMode.manualNumpad;
    }
    return ItemEntryMode.scan;
  }
}

enum WeightInputMode {
  manual('Manual Numpad'),
  auto('Auto Weighing Scale');

  const WeightInputMode(this.label);
  final String label;

  static WeightInputMode fromString(String? value) {
    return value?.trim().toLowerCase() == 'auto'
        ? WeightInputMode.auto
        : WeightInputMode.manual;
  }
}

enum InputSourceMode {
  uiForm('UI Form Editor'),
  json('JSON Payload'),
  csv('CSV / Excel Sheet');

  const InputSourceMode(this.label);
  final String label;

  static InputSourceMode fromString(String? val) {
    if (val == 'json') return InputSourceMode.json;
    if (val == 'csv') return InputSourceMode.csv;
    return InputSourceMode.uiForm;
  }
}

enum UiCustomMode {
  common('Same Items for All Orders'),
  perIteration('Custom Items Per Order');

  const UiCustomMode(this.label);
  final String label;

  static UiCustomMode fromString(String? val) {
    if (val == 'perIteration' || val == 'perOrder') {
      return UiCustomMode.perIteration;
    }
    return UiCustomMode.common;
  }
}

/// Single SKU item entry for an order automation test scenario.
class OrderItem {
  static final RegExp _numericBizerbaPattern = RegExp(r'^\d{8}\.\d{3}$');
  static final RegExp _shortCodePattern = RegExp(r'^\d{1,3}$');

  const OrderItem({
    required this.skuCode,
    this.type = SkuItemType.nonWeighed,
    this.weight,
    this.weightInputMode = WeightInputMode.manual,
    this.entryMode = ItemEntryMode.scan,
    this.rowId = '',
  });

  static int _rowSequence = 0;

  /// Creates a draft row with a stable identity for the configuration UI.
  /// The ID is not a POS value; it only prevents Flutter from reusing another
  /// row's text-field and dropdown state after add/remove operations.
  factory OrderItem.draft({
    String skuCode = '',
    SkuItemType type = SkuItemType.nonWeighed,
    double? weight,
    WeightInputMode weightInputMode = WeightInputMode.manual,
    ItemEntryMode entryMode = ItemEntryMode.scan,
  }) {
    _rowSequence++;
    final cleanCode = skuCode.trim();
    final resolvedType = _resolveType(cleanCode, type);

    return OrderItem(
      skuCode: skuCode,
      type: resolvedType,
      weight: weight,
      weightInputMode: weightInputMode,
      entryMode: entryMode,
      rowId: 'sku-${DateTime.now().microsecondsSinceEpoch}-$_rowSequence',
    );
  }

  final String skuCode;
  final SkuItemType type;
  final double? weight;
  final WeightInputMode weightInputMode;
  final ItemEntryMode entryMode;
  final String rowId;

  /// The type after applying the barcode contract.
  ///
  /// A Bizerba-formatted code is authoritative even if an imported payload
  /// incorrectly labels it `nonWeighed` or `weighed`.
  SkuItemType get effectiveType => type;

  bool get isWeighed => effectiveType == SkuItemType.weighed;
  bool get isBizerba => effectiveType == SkuItemType.bizerba;

  static bool isBizerbaCode(String code) {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    return cleanCode.toUpperCase().contains('W') ||
        _numericBizerbaPattern.hasMatch(cleanCode);
  }

  static bool isShortCode(String code) {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) return false;
    return _shortCodePattern.hasMatch(cleanCode);
  }

  static double? extractBizerbaWeight(String code) {
    final clean = code.trim();
    final wIndex = clean.toUpperCase().indexOf('W');
    if (wIndex != -1 && wIndex < clean.length - 1) {
      final sub = clean.substring(wIndex + 1);
      return double.tryParse(sub);
    }
    final dotIndex = clean.indexOf('.');
    if (dotIndex != -1 && dotIndex < clean.length - 1) {
      final sub = clean.substring(dotIndex + 1);
      return double.tryParse('0.$sub');
    }
    return null;
  }

  static SkuItemType _resolveType(String cleanCode, SkuItemType requestedType) {
    if (cleanCode.isEmpty) return requestedType;
    return isBizerbaCode(cleanCode) ? SkuItemType.bizerba : requestedType;
  }

  /// Returns the effective entry mode according to precedence rules:
  /// 1. Bizerba -> ItemEntryMode.scan
  /// 2. Explicit entryMode if not scan
  /// 3. Short code (1 to 3 numeric digits) -> ItemEntryMode.manualNumpad
  ItemEntryMode get effectiveEntryMode {
    final cleanCode = skuCode.trim();

    if (isBizerba) {
      return ItemEntryMode.scan;
    }

    if (entryMode != ItemEntryMode.scan) {
      return entryMode;
    }

    if (isShortCode(cleanCode)) {
      return ItemEntryMode.manualNumpad;
    }

    return entryMode;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'skuCode': skuCode,
    if (rowId.isNotEmpty) 'rowId': rowId,
    'type': effectiveType.name,
    'entryMode': effectiveEntryMode.name,
    'weightInputMode': weightInputMode.name,
    'isWeighed': isWeighed,
    if (weight != null) 'weight': weight,
  };

  factory OrderItem.fromJson(Map<String, Object?> json) {
    final typeStr =
        (json['type'] ?? json['item_type'] ?? json['itemType']) as String?;
    final entryModeStr =
        (json['entryMode'] ?? json['entry_mode'] ?? json['mode']) as String?;
    final isWeighedOld =
        ((json['isWeighed'] ?? json['is_weighed']) as bool?) ?? false;
    final isBizerbaOld =
        ((json['isBizerba'] ?? json['is_bizerba']) as bool?) ?? false;
    final rawSkuCode =
        '${json['skuCode'] ?? json['sku_code'] ?? json['code'] ?? ''}';
    final cleanCode = rawSkuCode.trim();

    final requestedType = typeStr != null
        ? SkuItemType.fromString(typeStr)
        : (isBizerbaOld
              ? SkuItemType.bizerba
              : (isWeighedOld ? SkuItemType.weighed : SkuItemType.nonWeighed));
    final resolvedType = _resolveType(cleanCode, requestedType);

    final parsedMode = ItemEntryMode.fromString(entryModeStr);

    return OrderItem(
      skuCode: rawSkuCode,
      type: resolvedType,
      weight:
          ((json['weight'] ?? json['weight_kg'] ?? json['weightKg']) as num?)
              ?.toDouble(),
      weightInputMode: WeightInputMode.fromString(
        (json['weightInputMode'] ?? json['weight_input_mode']) as String?,
      ),
      entryMode: parsedMode,
      rowId:
          ((json['rowId'] ?? json['row_id']) as String?) ??
          OrderItem.draft().rowId,
    );
  }

  static const Object _weightSentinel = Object();

  OrderItem copyWith({
    String? skuCode,
    SkuItemType? type,
    Object? weight = _weightSentinel,
    WeightInputMode? weightInputMode,
    ItemEntryMode? entryMode,
    String? rowId,
  }) {
    final newSkuCode = skuCode ?? this.skuCode;
    final resolvedType = type ?? this.type;

    final double? resolvedWeight = resolvedType == SkuItemType.weighed
        ? (identical(weight, _weightSentinel) ? this.weight : weight as double?)
        : null;

    return OrderItem(
      skuCode: newSkuCode,
      type: resolvedType,
      weight: resolvedWeight,
      weightInputMode: weightInputMode ?? this.weightInputMode,
      entryMode: entryMode ?? this.entryMode,
      rowId: rowId ?? this.rowId,
    );
  }
}

/// Scenario definition for an Order & Payment automation suite run.
class OrderScenario {
  const OrderScenario({
    required this.id,
    required this.name,
    this.loginId,
    this.password,
    this.unlockPin,
    required this.items,
    this.ordersCount = 1,
    this.inputSourceMode = InputSourceMode.uiForm,
    this.uiCustomMode = UiCustomMode.common,
    this.perIterationItems = const <int, List<OrderItem>>{},
    this.rawJson = defaultSampleJson,
    this.rawCsv = defaultSampleCsv,
    this.openingFloatAmount = 0.0,
  });

  final String id;
  final String name;
  final String? loginId;
  final String? password;
  final String? unlockPin;
  final List<OrderItem> items;
  final int ordersCount;
  final InputSourceMode inputSourceMode;
  final UiCustomMode uiCustomMode;
  final Map<int, List<OrderItem>> perIterationItems;
  final String rawJson;
  final String rawCsv;
  final double openingFloatAmount;

  static final OrderScenario sampleScenario = OrderScenario(
    id: 'order_cash_payment_default',
    name: 'Order & Cash Payment Default Scenario',
    items: const <OrderItem>[
      OrderItem(
        skuCode: '',
        type: SkuItemType.nonWeighed,
        entryMode: ItemEntryMode.scan,
        rowId: 'common-initial',
      ),
    ],
    ordersCount: 1,
  );

  static const String defaultSampleJson = '''[
  {
    "order": 1,
    "items": [
      { "skuCode": "3", "type": "nonWeighed", "entryMode": "scan" },
      { "skuCode": "21", "type": "nonWeighed", "entryMode": "manual" }
    ]
  },
  {
    "order": 2,
    "items": [
      { "skuCode": "10000001W2.45", "type": "bizerba", "entryMode": "scan" },
      { "skuCode": "10000002", "type": "weighed", "weight": 2.345, "entryMode": "manual" }
    ]
  }
]''';

  /// Excel-compatible CSV layout. `ItemType` and `EntryMode` use the same
  /// values offered by the UI dropdowns.
  static const String defaultSampleCsv = '''Order,SKU,ItemType,Weight,EntryMode
1,3,nonWeighed,,scan
1,21,nonWeighed,,manual
2,10000001W2.45,bizerba,,scan
2,10000002,weighed,2.345,manual
3,3,nonWeighed,,scan''';

  static Map<int, List<OrderItem>> parseJsonOrders(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return <int, List<OrderItem>>{};

      final Map<int, List<OrderItem>> resultMap = <int, List<OrderItem>>{};
      for (final orderObj in decoded) {
        if (orderObj is Map<String, dynamic>) {
          final orderNum =
              (orderObj['order'] as num?)?.toInt() ?? (resultMap.length + 1);
          final itemsList = orderObj['items'];
          final List<OrderItem> parsedItems = <OrderItem>[];

          if (itemsList is List) {
            for (final itemObj in itemsList) {
              if (itemObj is Map<String, dynamic>) {
                parsedItems.add(OrderItem.fromJson(itemObj));
              }
            }
          }

          if (parsedItems.isNotEmpty) {
            resultMap[orderNum] = parsedItems;
          }
        }
      }
      return resultMap;
    } catch (_) {
      return <int, List<OrderItem>>{};
    }
  }

  static Map<int, List<OrderItem>> parseCsvOrders(String rawCsv) {
    try {
      final lines = rawCsv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isEmpty) return <int, List<OrderItem>>{};

      final Map<int, List<OrderItem>> resultMap = <int, List<OrderItem>>{};
      final hasHeader = lines.first.toLowerCase().contains('order');
      final startIndex = hasHeader ? 1 : 0;
      final headerIndexes = <String, int>{};
      if (hasHeader) {
        final headers = lines.first
            .split(',')
            .map((header) => header.trim().toLowerCase())
            .toList();
        for (var index = 0; index < headers.length; index++) {
          headerIndexes[headers[index]] = index;
        }
      }

      String valueFor(List<String> columns, String header, int fallbackIndex) {
        final index = headerIndexes[header] ?? fallbackIndex;
        return index >= 0 && index < columns.length ? columns[index] : '';
      }

      for (int i = startIndex; i < lines.length; i++) {
        final cols = lines[i].split(',').map((c) => c.trim()).toList();
        if (cols.length < 2) continue;

        final orderNum = int.tryParse(valueFor(cols, 'order', 0)) ?? 1;
        final skuCode = valueFor(cols, 'sku', 1);
        final weight = double.tryParse(valueFor(cols, 'weight', 3));
        final explicitType = valueFor(cols, 'itemtype', -1);
        final legacyIsBizerba =
            valueFor(cols, 'isbizerba', 2).toLowerCase() == 'true';
        final entryModeStr = valueFor(cols, 'entrymode', 4);

        final resolvedType = explicitType.isNotEmpty
            ? SkuItemType.fromString(explicitType)
            : (legacyIsBizerba
                  ? SkuItemType.bizerba
                  : (weight != null
                        ? SkuItemType.weighed
                        : SkuItemType.nonWeighed));

        final item = OrderItem.draft(
          skuCode: skuCode,
          type: resolvedType,
          weight: weight,
          entryMode: ItemEntryMode.fromString(entryModeStr),
        );

        final currentList = resultMap[orderNum] ?? <OrderItem>[];
        currentList.add(item);
        resultMap[orderNum] = currentList;
      }

      return resultMap;
    } catch (_) {
      return <int, List<OrderItem>>{};
    }
  }

  int get effectiveOrdersCount {
    if (inputSourceMode == InputSourceMode.json) {
      final parsed = parseJsonOrders(rawJson);
      return parsed.isNotEmpty ? parsed.length : ordersCount;
    }
    if (inputSourceMode == InputSourceMode.csv) {
      final parsed = parseCsvOrders(rawCsv);
      return parsed.isNotEmpty ? parsed.length : ordersCount;
    }
    return ordersCount;
  }

  List<OrderItem> getItemsForIteration(int iterNumber) {
    if (inputSourceMode == InputSourceMode.json) {
      final parsed = parseJsonOrders(rawJson);
      return parsed[iterNumber] ?? items;
    }
    if (inputSourceMode == InputSourceMode.csv) {
      final parsed = parseCsvOrders(rawCsv);
      return parsed[iterNumber] ?? items;
    }

    // AI plans may encode a single order in perIterationItems even though the
    // common UI model normally uses items. Honor the explicit payload whenever
    // per-iteration mode is selected so the runner cannot silently see zero
    // SKUs for a valid one-order plan.
    if (uiCustomMode == UiCustomMode.perIteration) {
      return perIterationItems[iterNumber] ?? items;
    }

    return items;
  }

  /// Returns the items that will actually be punched by this scenario. This
  /// is intentionally different from [items]: per-iteration AI plans keep
  /// their items in [perIterationItems] and may have an empty common list.
  List<OrderItem> itemsForAllIterations() {
    final all = <OrderItem>[...items];
    for (final iterationItems in perIterationItems.values) {
      all.addAll(iterationItems);
    }
    return all.where((item) => item.skuCode.trim().isNotEmpty).toList();
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    // Credentials are runtime-only inputs from the secure vault. Scenario
    // exports can be attached to reports, so they must never contain secrets.
    'items': items.map((i) => i.toJson()).toList(),
    'ordersCount': ordersCount,
    'inputSourceMode': inputSourceMode.name,
    'uiCustomMode': uiCustomMode.name,
    'perIterationItems': perIterationItems.map(
      (k, v) => MapEntry(k.toString(), v.map((i) => i.toJson()).toList()),
    ),
    'rawJson': rawJson,
    'rawCsv': rawCsv,
    'openingFloatAmount': openingFloatAmount,
  };

  factory OrderScenario.fromJson(Map<String, Object?> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? <dynamic>[];
    final itemsList = itemsJson
        .map((i) => OrderItem.fromJson(i as Map<String, Object?>))
        .toList();

    final perIterationJson =
        json['perIterationItems'] as Map<String, Object?>? ??
        const <String, Object?>{};
    final perIterationItems = <int, List<OrderItem>>{};
    for (final entry in perIterationJson.entries) {
      final iteration = int.tryParse(entry.key);
      final rawItems = entry.value;
      if (iteration == null || rawItems is! List) continue;
      perIterationItems[iteration] = rawItems
          .whereType<Map>()
          .map((item) => OrderItem.fromJson(item.cast<String, Object?>()))
          .toList();
    }

    return OrderScenario(
      id: json['id'] as String,
      name: json['name'] as String,
      loginId: json['loginId'] as String?,
      password: json['password'] as String?,
      unlockPin: json['unlockPin'] as String?,
      items: itemsList,
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 1,
      inputSourceMode: InputSourceMode.fromString(
        json['inputSourceMode'] as String?,
      ),
      uiCustomMode: UiCustomMode.fromString(json['uiCustomMode'] as String?),
      perIterationItems: perIterationItems,
      rawJson: (json['rawJson'] as String?) ?? defaultSampleJson,
      rawCsv: (json['rawCsv'] as String?) ?? defaultSampleCsv,
      openingFloatAmount:
          (json['openingFloatAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
