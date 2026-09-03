import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_scenario.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/sku_item_row.dart';

/// Helper container managing stateful TextEditingControllers per SKU item row.
class SkuRowControllers {
  SkuRowControllers({required String skuCode, double? weight})
    : skuCodeController = TextEditingController(text: skuCode),
      weightController = TextEditingController(
        text: weight != null ? weight.toString() : '',
      );

  final TextEditingController skuCodeController;
  final TextEditingController weightController;

  void dispose() {
    skuCodeController.dispose();
    weightController.dispose();
  }
}

/// Scenario Inputs & Config Tab Widget for Order Suite supporting 3 Input Modes:
/// 1. UI Form Editor (Common vs Custom per Iteration Cards)
/// 2. JSON Skeleton Editor (with File Upload & Syntax Preview)
/// 3. CSV / Excel Sheet Import (with File Upload & Parsed Data Table)
class OrderConfigTab extends StatefulWidget {
  const OrderConfigTab({
    super.key,
    required this.orderScenario,
    required this.rowControllers,
    required this.ordersCountController,
    required this.validationError,
    required this.running,
    required this.onAddSkuItem,
    required this.onRemoveSkuItem,
    required this.onUpdateSkuItem,
    required this.onUpdateOrdersCount,
    required this.onUpdateInputSourceMode,
    required this.onUpdateUiCustomMode,
    required this.onUpdatePerIterationItems,
    required this.onUpdateRawJson,
    required this.onUpdateRawCsv,
  });

  final OrderScenario orderScenario;
  final List<SkuRowControllers> rowControllers;
  final TextEditingController ordersCountController;
  final String? validationError;
  final bool running;

  final VoidCallback onAddSkuItem;
  final ValueChanged<int> onRemoveSkuItem;
  final Function(int index, OrderItem updated) onUpdateSkuItem;
  final ValueChanged<int> onUpdateOrdersCount;

  final ValueChanged<InputSourceMode> onUpdateInputSourceMode;
  final ValueChanged<UiCustomMode> onUpdateUiCustomMode;
  final ValueChanged<Map<int, List<OrderItem>>> onUpdatePerIterationItems;
  final ValueChanged<String> onUpdateRawJson;
  final ValueChanged<String> onUpdateRawCsv;

  @override
  State<OrderConfigTab> createState() => _OrderConfigTabState();
}

class _OrderConfigTabState extends State<OrderConfigTab> {
  int _selectedIterationIndex = 1;
  late final TextEditingController _jsonController;
  late final TextEditingController _csvController;
  String? _uploadedJsonFileName;
  String? _uploadedCsvFileName;

  @override
  void initState() {
    super.initState();
    _jsonController = TextEditingController(text: widget.orderScenario.rawJson);
    _csvController = TextEditingController(text: widget.orderScenario.rawCsv);
  }

  @override
  void didUpdateWidget(OrderConfigTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.orderScenario.rawJson != oldWidget.orderScenario.rawJson &&
        _jsonController.text != widget.orderScenario.rawJson) {
      _jsonController.text = widget.orderScenario.rawJson;
    }
    if (widget.orderScenario.rawCsv != oldWidget.orderScenario.rawCsv &&
        _csvController.text != widget.orderScenario.rawCsv) {
      _csvController.text = widget.orderScenario.rawCsv;
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoadJsonFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json', 'txt'],
        allowMultiple: false,
        withData: true,
      );

      if (res != null) {
        final selectedFile = res.files.single;
        final content = utf8.decode(await _readSelectedFile(selectedFile));
        setState(() {
          _uploadedJsonFileName = selectedFile.name;
          _jsonController.text = _formatBeautifiedJson(content);
        });
        widget.onUpdateRawJson(_formatBeautifiedJson(content));
      }
    } catch (error) {
      _showUploadError('Unable to load JSON file: $error');
    }
  }

  Future<void> _pickAndLoadCsvFile() async {
    try {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'xlsx', 'txt'],
        allowMultiple: false,
        withData: true,
      );

      if (res != null) {
        final selectedFile = res.files.single;
        final bytes = await _readSelectedFile(selectedFile);
        final extension = (selectedFile.extension ?? '').trim().toLowerCase();
        final content = extension == 'xlsx'
            ? _readXlsxAsCsv(bytes)
            : utf8.decode(bytes);

        setState(() {
          _uploadedCsvFileName = selectedFile.name;
          _csvController.text = content;
        });
        widget.onUpdateRawCsv(content);
      }
    } catch (error) {
      _showUploadError('Unable to load spreadsheet file: $error');
    }
  }

  Future<Uint8List> _readSelectedFile(PlatformFile selectedFile) async {
    final inMemoryBytes = selectedFile.bytes;
    if (inMemoryBytes != null) return inMemoryBytes;

    final path = selectedFile.path;
    if (path == null || path.isEmpty) {
      throw StateError('The selected file is not accessible from this device.');
    }
    return File(path).readAsBytes();
  }

  void _showUploadError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  /// Converts the first worksheet into the exact column-oriented CSV format
  /// consumed by [OrderScenario.parseCsvOrders]. Excel users need only one
  /// sheet and one header row.
  String _readXlsxAsCsv(List<int> bytes) {
    final workbook = excel.Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return '';
    final sheet = workbook.tables.values.first;
    return sheet.rows
        .map(
          (row) => row
              .map((cell) => _escapeCsvCell(cell?.value?.toString() ?? ''))
              .join(','),
        )
        .join('\n');
  }

  String _escapeCsvCell(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  String _formatBeautifiedJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenario = widget.orderScenario;
    final activeSource = scenario.inputSourceMode;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Validation Error Banner (if any)
          if (widget.validationError != null) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.validationError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Top 3 Input Mode Selection Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _buildMainSourceTab(
                    mode: InputSourceMode.uiForm,
                    icon: Icons.edit_note_rounded,
                    label: '1. UI Form Editor',
                    isSelected: activeSource == InputSourceMode.uiForm,
                  ),
                ),
                Expanded(
                  child: _buildMainSourceTab(
                    mode: InputSourceMode.json,
                    icon: Icons.code_rounded,
                    label: '2. JSON Skeleton',
                    isSelected: activeSource == InputSourceMode.json,
                  ),
                ),
                Expanded(
                  child: _buildMainSourceTab(
                    mode: InputSourceMode.csv,
                    icon: Icons.table_chart_outlined,
                    label: '3. Excel / CSV File',
                    isSelected: activeSource == InputSourceMode.csv,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- MODE 1: UI FORM EDITOR ---
          if (activeSource == InputSourceMode.uiForm) ...<Widget>[
            _buildUiFormSection(scenario),
          ] else if (activeSource == InputSourceMode.json) ...<Widget>[
            // --- MODE 2: JSON SKELETON MODE ---
            _buildJsonSection(scenario),
          ] else ...<Widget>[
            // --- MODE 3: CSV / EXCEL MODE ---
            _buildCsvSection(scenario),
          ],
        ],
      ),
    );
  }

  Widget _buildMainSourceTab({
    required InputSourceMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: widget.running ? null : () => widget.onUpdateInputSourceMode(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUiFormSection(OrderScenario scenario) {
    final isCustomPerIter = scenario.uiCustomMode == UiCustomMode.perIteration;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Orders to Punch Stepper Control
          Row(
            children: <Widget>[
              const Icon(
                Icons.repeat_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              const Text(
                'Orders to Punch (Back-to-Back Loop)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                onPressed: widget.running || scenario.ordersCount <= 1
                    ? null
                    : () =>
                          widget.onUpdateOrdersCount(scenario.ordersCount - 1),
              ),
              SizedBox(
                width: 50,
                child: TextField(
                  controller: widget.ordersCountController,
                  enabled: !widget.running,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 1;
                    widget.onUpdateOrdersCount(parsed);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: widget.running || scenario.ordersCount >= 50
                    ? null
                    : () =>
                          widget.onUpdateOrdersCount(scenario.ordersCount + 1),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Common vs Custom Sub-Toggle Switch
          Row(
            children: <Widget>[
              ChoiceChip(
                label: const Text('Common Payload (Same for All)'),
                selected: !isCustomPerIter,
                selectedColor: const Color(0xFFEFF6FF),
                side: BorderSide(
                  color: !isCustomPerIter
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFCBD5E1),
                ),
                onSelected: widget.running
                    ? null
                    : (val) {
                        if (val) {
                          widget.onUpdateUiCustomMode(UiCustomMode.common);
                        }
                      },
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Custom Payload per Iteration'),
                selected: isCustomPerIter,
                selectedColor: const Color(0xFFEFF6FF),
                side: BorderSide(
                  color: isCustomPerIter
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFCBD5E1),
                ),
                onSelected: widget.running
                    ? null
                    : (val) {
                        if (val) {
                          widget.onUpdateUiCustomMode(
                            UiCustomMode.perIteration,
                          );
                        }
                      },
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Mode 1A: Common Payload Editor
          if (!isCustomPerIter) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.list_alt_rounded,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Common Test SKU Items (Punched for All Orders)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.running ? null : widget.onAddSkuItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add SKU Item'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...scenario.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final ctrls = index < widget.rowControllers.length
                  ? widget.rowControllers[index]
                  : null;

              return SkuItemRow(
                key: ValueKey<String>(
                  'common-${item.rowId.isEmpty ? index : item.rowId}',
                ),
                index: index,
                item: item,
                skuCodeController: ctrls?.skuCodeController,
                weightController: ctrls?.weightController,
                running: widget.running,
                onUpdateItem: (updated) =>
                    widget.onUpdateSkuItem(index, updated),
                onRemoveItem: () => widget.onRemoveSkuItem(index),
              );
            }),
          ] else ...<Widget>[
            // Mode 1B: Custom Payload per Iteration Cards
            Row(
              children: <Widget>[
                const Icon(
                  Icons.layers_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Order Iteration (${scenario.ordersCount} Total):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Iterations Tabs Bar (Order #1, Order #2, Order #3...)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List<Widget>.generate(scenario.ordersCount, (idx) {
                  final iterNum = idx + 1;
                  final isSel = _selectedIterationIndex == iterNum;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Order #$iterNum'),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedIterationIndex = iterNum);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // Custom Items Table for Selected Iteration
            _buildPerIterationItemsEditor(scenario, _selectedIterationIndex),
          ],
        ],
      ),
    );
  }

  Widget _buildPerIterationItemsEditor(OrderScenario scenario, int iterNumber) {
    final currentList =
        scenario.perIterationItems[iterNumber] ??
        <OrderItem>[OrderItem.draft()];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Custom SKU Items for Order #$iterNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.running
                    ? null
                    : () {
                        final updatedMap = Map<int, List<OrderItem>>.from(
                          scenario.perIterationItems,
                        );
                        final newList = List<OrderItem>.from(currentList)
                          ..add(OrderItem.draft());
                        updatedMap[iterNumber] = newList;
                        widget.onUpdatePerIterationItems(updatedMap);
                      },
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add SKU to Order #',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...currentList.asMap().entries.map((entry) {
            final itemIdx = entry.key;
            final item = entry.value;

            return _PerIterationSkuRow(
              key: ValueKey<String>(
                'per_iter_${iterNumber}_${item.rowId.isEmpty ? itemIdx : item.rowId}',
              ),
              index: itemIdx,
              item: item,
              running: widget.running,
              onUpdateItem: (newItem) {
                final updatedMap = Map<int, List<OrderItem>>.from(
                  scenario.perIterationItems,
                );
                final newList = List<OrderItem>.from(currentList);
                newList[itemIdx] = newItem;
                updatedMap[iterNumber] = newList;
                widget.onUpdatePerIterationItems(updatedMap);
              },
              onRemoveItem: () {
                final updatedMap = Map<int, List<OrderItem>>.from(
                  scenario.perIterationItems,
                );
                final newList = List<OrderItem>.from(currentList);
                if (newList.length > 1) {
                  newList.removeAt(itemIdx);
                  updatedMap[iterNumber] = newList;
                  widget.onUpdatePerIterationItems(updatedMap);
                }
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJsonSection(OrderScenario scenario) {
    final parsedMap = OrderScenario.parseJsonOrders(scenario.rawJson);
    final count = parsedMap.length;
    final isUploaded = _uploadedJsonFileName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row 1: Title & Auto-Detected Badge
          Row(
            children: <Widget>[
              const Icon(
                Icons.code_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              const Text(
                'JSON Payload Skeleton Editor',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  isUploaded
                      ? '📄 $_uploadedJsonFileName ($count Orders)'
                      : '$count Orders Auto-Detected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Header Row 2: Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: widget.running ? null : _pickAndLoadJsonFile,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text(
                  'Upload JSON File (.json)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.running
                    ? null
                    : () {
                        setState(() => _uploadedJsonFileName = null);
                        widget.onUpdateRawJson(OrderScenario.defaultSampleJson);
                      },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text(
                  'Reset Sample JSON',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Beautified Light Grey Code Container (Editable & Syntax Formatted)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.schema_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUploaded
                          ? 'Uploaded JSON Payload Structure [$_uploadedJsonFileName]:'
                          : 'Sample JSON Payload Structure:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _jsonController,
                    enabled: !widget.running,
                    minLines: 16,
                    maxLines: 22,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Paste JSON array of order payloads...',
                    ),
                    onChanged: (val) => widget.onUpdateRawJson(val),
                  ),
                ),
              ],
            ),
          ),

          // IF FILE IS UPLOADED: Render Parsed Data Table directly below sample JSON container
          if (isUploaded) ...<Widget>[
            const SizedBox(height: 14),
            _buildParsedOrdersTableCard(parsedMap, _uploadedJsonFileName!),
          ],
        ],
      ),
    );
  }

  Widget _buildCsvSection(OrderScenario scenario) {
    final parsedMap = OrderScenario.parseCsvOrders(scenario.rawCsv);
    final count = parsedMap.length;
    final isUploaded = _uploadedCsvFileName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row 1: Title & Auto-Detected Badge
          Row(
            children: <Widget>[
              const Icon(
                Icons.table_chart_outlined,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              const Text(
                'Excel / CSV Format File Upload',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  isUploaded
                      ? '📄 $_uploadedCsvFileName ($count Orders)'
                      : '$count Orders Auto-Detected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Header Row 2: Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: widget.running ? null : _pickAndLoadCsvFile,
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text(
                  'Upload Excel / CSV File (.csv, .xlsx)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.running
                    ? null
                    : () {
                        setState(() => _uploadedCsvFileName = null);
                        widget.onUpdateRawCsv(OrderScenario.defaultSampleCsv);
                      },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text(
                  'Reset Sample CSV',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Formatted Excel Table Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.table_rows_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUploaded
                          ? 'Uploaded Excel / CSV File Content [$_uploadedCsvFileName]:'
                          : 'Expected Excel / CSV Sheet Columns Structure:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                const Text(
                  'Use: Order, SKU, ItemType, Weight, EntryMode. '
                  'ItemType values: nonWeighed, weighed, bizerba. '
                  'EntryMode values: scan, manual. Older IsBizerba sheets remain supported.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Column guide',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '• ItemType = nonWeighed: normal SKU, no weight.\n'
                        '• ItemType = weighed: enter Weight in kg (example: 1.250).\n'
                        '• ItemType = bizerba: full scale barcode; leave Weight empty.\n'
                        '• EntryMode = scan: send the SKU/barcode to the scan field.\n'
                        '• EntryMode = manual: press the POS custom numpad for the SKU.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF78350F),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Table(
                  border: TableBorder.all(
                    color: const Color(0xFFCBD5E1),
                    width: 1,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  children: const <TableRow>[
                    TableRow(
                      decoration: BoxDecoration(color: Color(0xFFEFF6FF)),
                      children: <Widget>[
                        _SpreadsheetCell('Order', header: true),
                        _SpreadsheetCell('SKU', header: true),
                        _SpreadsheetCell('ItemType', header: true),
                        _SpreadsheetCell('Weight (kg)', header: true),
                        _SpreadsheetCell('EntryMode', header: true),
                      ],
                    ),
                    TableRow(
                      children: <Widget>[
                        _SpreadsheetCell('1'),
                        _SpreadsheetCell('1001'),
                        _SpreadsheetCell('nonWeighed'),
                        _SpreadsheetCell(''),
                        _SpreadsheetCell('scan'),
                      ],
                    ),
                    TableRow(
                      children: <Widget>[
                        _SpreadsheetCell('1'),
                        _SpreadsheetCell('1002'),
                        _SpreadsheetCell('weighed'),
                        _SpreadsheetCell('1.250'),
                        _SpreadsheetCell('manual'),
                      ],
                    ),
                    TableRow(
                      children: <Widget>[
                        _SpreadsheetCell('2'),
                        _SpreadsheetCell('2000011017354'),
                        _SpreadsheetCell('bizerba'),
                        _SpreadsheetCell(''),
                        _SpreadsheetCell('scan'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Kept offstage temporarily for backwards-reference only. The
                // visible table above is the canonical import contract.
                Offstage(
                  offstage: true,
                  child: Table(
                    border: TableBorder.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    children: const <TableRow>[
                      TableRow(
                        decoration: BoxDecoration(color: Color(0xFFEFF6FF)),
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Order',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'SKU',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'IsBizerba',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Weight (kg)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('1', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('1001', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'false',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('1', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('1002', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'false',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('2', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              '2000011017354',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('true', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      TableRow(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('2', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('3002', style: TextStyle(fontSize: 11)),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'false',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('1.5', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // IF FILE IS UPLOADED: Render Parsed Data Table directly below format container
          if (isUploaded) ...<Widget>[
            const SizedBox(height: 14),
            _buildParsedOrdersTableCard(parsedMap, _uploadedCsvFileName!),
          ],
        ],
      ),
    );
  }

  Widget _buildParsedOrdersTableCard(
    Map<int, List<OrderItem>> parsedMap,
    String fileName,
  ) {
    final rows = <TableRow>[];

    // Table Header
    rows.add(
      const TableRow(
        decoration: BoxDecoration(color: Color(0xFFEFF6FF)),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Order #',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'SKU / Barcode String',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Entry Mode',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Item Type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Weight (kg)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );

    // Data Rows
    parsedMap.forEach((orderNum, items) {
      for (final item in items) {
        rows.add(
          TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text('$orderNum', style: const TextStyle(fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  item.skuCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  item.entryMode.label,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  item.type.label,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  item.weight != null ? '${item.weight} kg' : '-',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                'Parsed Data Table from [$fileName]:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Table(
            border: TableBorder.all(
              color: const Color(0xFFCBD5E1),
              width: 1,
              borderRadius: BorderRadius.circular(4),
            ),
            children: rows,
          ),
        ],
      ),
    );
  }
}

class _PerIterationSkuRow extends StatefulWidget {
  const _PerIterationSkuRow({
    super.key,
    required this.index,
    required this.item,
    required this.running,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  final int index;
  final OrderItem item;
  final bool running;
  final ValueChanged<OrderItem> onUpdateItem;
  final VoidCallback onRemoveItem;

  @override
  State<_PerIterationSkuRow> createState() => _PerIterationSkuRowState();
}

class _PerIterationSkuRowState extends State<_PerIterationSkuRow> {
  late final TextEditingController _skuController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.item.skuCode);
    _weightController = TextEditingController(
      text: widget.item.weight != null ? widget.item.weight.toString() : '',
    );
  }

  @override
  void didUpdateWidget(_PerIterationSkuRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.skuCode != _skuController.text) {
      _skuController.text = widget.item.skuCode;
    }
    final currentParsedWeight = double.tryParse(_weightController.text);
    if (currentParsedWeight != widget.item.weight) {
      _weightController.text = widget.item.weight != null
          ? widget.item.weight.toString()
          : '';
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkuItemRow(
      index: widget.index,
      item: widget.item,
      skuCodeController: _skuController,
      weightController: _weightController,
      running: widget.running,
      onUpdateItem: widget.onUpdateItem,
      onRemoveItem: widget.onRemoveItem,
    );
  }
}

class _SpreadsheetCell extends StatelessWidget {
  const _SpreadsheetCell(this.text, {this.header = false});

  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: header ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
          color: header ? const Color(0xFF1D4ED8) : const Color(0xFF1F2937),
        ),
      ),
    );
  }
}
