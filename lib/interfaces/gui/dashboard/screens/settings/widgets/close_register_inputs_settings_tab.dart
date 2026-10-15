import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

class CloseRegisterInputsSettingsTab extends StatefulWidget {
  const CloseRegisterInputsSettingsTab({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    this.loadInput,
    this.saveInput,
    this.onProfileChanged,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final RegisterInputLoader? loadInput;
  final RegisterInputSaver? saveInput;
  final ValueChanged<QaProfile>? onProfileChanged;

  @override
  State<CloseRegisterInputsSettingsTab> createState() =>
      _CloseRegisterInputsSettingsTabState();
}

class _CloseRegisterInputsSettingsTabState
    extends State<CloseRegisterInputsSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '1000');
  final _notesController = TextEditingController();

  final Map<int, TextEditingController> _noteControllers =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _coinControllers =
      <int, TextEditingController>{};

  bool _loading = true;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isUpdatingFromDenominations = false;

  static const double _minAmount = QaRegisterInput.minCloseAmount;
  static const double _maxAmount = QaRegisterInput.maxCloseAmount;

  @override
  void initState() {
    super.initState();
    for (final d in QaRegisterInput.supportedDenominations) {
      if (QaRegisterInput.hasNotes(d)) {
        _noteControllers[d] = TextEditingController(text: '0');
      }
      if (QaRegisterInput.hasCoins(d)) {
        _coinControllers[d] = TextEditingController(text: '0');
      }
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant CloseRegisterInputsSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfile.id != widget.selectedProfile.id) {
      _load();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    for (final c in _coinControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
    });

    final loader = widget.loadInput;
    QaRegisterInput input;
    if (loader != null) {
      input = await loader(widget.selectedProfile.id);
    } else {
      input = await SharedPreferencesQaRegisterInputRepository().read(
        widget.selectedProfile.id,
      );
    }

    if (!mounted) return;
    final clamped = input.closeTotalAmount.clamp(_minAmount, _maxAmount);

    for (final d in QaRegisterInput.supportedDenominations) {
      if (QaRegisterInput.hasNotes(d)) {
        _noteControllers[d]!.text = (input.closeNotesMap[d] ?? 0).toString();
      }
      if (QaRegisterInput.hasCoins(d)) {
        _coinControllers[d]!.text = (input.closeCoinsMap[d] ?? 0).toString();
      }
    }

    // If both maps are empty and there was an existing positive total amount,
    // initialize breakdown greedily so counts immediately match the total.
    if (input.closeNotesMap.isEmpty &&
        input.closeCoinsMap.isEmpty &&
        clamped > 0) {
      var rem = clamped.toInt();
      for (final d in QaRegisterInput.supportedDenominations) {
        final count = rem ~/ d;
        rem %= d;
        if (QaRegisterInput.hasNotes(d)) {
          _noteControllers[d]!.text = count.toString();
        }
        if (QaRegisterInput.hasCoins(d)) {
          _coinControllers[d]!.text = (!QaRegisterInput.hasNotes(d) ? count : 0)
              .toString();
        }
      }
    }

    setState(() {
      _amountController.text = _formatAmount(clamped);
      _notesController.text = input.closeNotes;
      _loading = false;
    });
  }

  String _formatAmount(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  int get _computedTotal {
    var sum = 0;
    for (final d in QaRegisterInput.supportedDenominations) {
      final n = QaRegisterInput.hasNotes(d)
          ? (int.tryParse(_noteControllers[d]?.text.trim() ?? '0') ?? 0)
          : 0;
      final c = QaRegisterInput.hasCoins(d)
          ? (int.tryParse(_coinControllers[d]?.text.trim() ?? '0') ?? 0)
          : 0;
      sum += (d * n) + (d * c);
    }
    return sum;
  }

  void _onDenominationChanged() {
    _isUpdatingFromDenominations = true;
    final sum = _computedTotal;
    _amountController.text = sum.toString();
    _isUpdatingFromDenominations = false;
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    } else {
      setState(() {});
    }
  }

  void _onAmountTextChanged(String text) {
    if (_isUpdatingFromDenominations) return;
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    }
    final parsed = double.tryParse(text.trim())?.toInt() ?? 0;
    var rem = parsed;
    for (final d in QaRegisterInput.supportedDenominations) {
      final count = rem ~/ d;
      rem %= d;
      if (QaRegisterInput.hasNotes(d)) {
        _noteControllers[d]!.text = count.toString();
      }
      if (QaRegisterInput.hasCoins(d)) {
        _coinControllers[d]!.text = (!QaRegisterInput.hasNotes(d) ? count : 0)
            .toString();
      }
    }
    setState(() {});
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Closing total cash amount is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid numeric amount';
    }
    if (parsed < _minAmount) {
      return 'Amount must be at least ₹${_formatAmount(_minAmount)}';
    }
    if (parsed > _maxAmount) {
      return 'Amount cannot exceed ₹${_formatAmount(_maxAmount)}';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount =
        double.tryParse(_amountController.text.trim()) ?? 1000.0;

    final notesMap = <int, int>{};
    final coinsMap = <int, int>{};
    for (final d in QaRegisterInput.supportedDenominations) {
      if (QaRegisterInput.hasNotes(d)) {
        final n = int.tryParse(_noteControllers[d]?.text.trim() ?? '0') ?? 0;
        if (n > 0) notesMap[d] = n;
      }
      if (QaRegisterInput.hasCoins(d)) {
        final c = int.tryParse(_coinControllers[d]?.text.trim() ?? '0') ?? 0;
        if (c > 0) coinsMap[d] = c;
      }
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    try {
      final loader = widget.loadInput;
      final currentInput = loader != null
          ? await loader(widget.selectedProfile.id)
          : await SharedPreferencesQaRegisterInputRepository().read(
              widget.selectedProfile.id,
            );

      final input = currentInput.copyWith(
        closeTotalAmount: parsedAmount,
        closeNotesMap: notesMap,
        closeCoinsMap: coinsMap,
        closeNotes: _notesController.text.trim(),
      );

      final saver = widget.saveInput;
      if (saver != null) {
        await saver(widget.selectedProfile.id, input);
      } else {
        await SharedPreferencesQaRegisterInputRepository().write(
          widget.selectedProfile.id,
          input,
        );
      }

      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage =
            'Saved Close Register total cash: ₹${_formatAmount(parsedAmount)} for ${widget.selectedProfile.label}.';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage = 'Failed to save close register inputs: $e';
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Form(
      key: _formKey,
      child: SettingsFormCard(
        children: <Widget>[
          // Amount input field
          const Text(
            'Closing Total Cash Amount (₹0 – ₹100,000) *',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey<String>('close-register-total-amount'),
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1F2937),
              ),
              hintText: 'Enter closing total cash amount',
              helperText:
                  'This total cash will be automatically distributed into notes and coins denominations below, or calculated from your inputs.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            validator: _validateAmount,
            onChanged: _onAmountTextChanged,
          ),
          const SizedBox(height: 20),

          // Cash Denominations Section (Notes & Coins)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Notes & Coins Breakdown',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              Text(
                'Sum: ₹$_computedTotal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: <Widget>[
                // Table header
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Denom',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Notes Count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Coins Count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Subtotal',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 12, thickness: 1),
                // Denomination rows
                ...QaRegisterInput.supportedDenominations.map((d) {
                  final n = QaRegisterInput.hasNotes(d)
                      ? (int.tryParse(
                              _noteControllers[d]?.text.trim() ?? '0',
                            ) ??
                            0)
                      : 0;
                  final c = QaRegisterInput.hasCoins(d)
                      ? (int.tryParse(
                              _coinControllers[d]?.text.trim() ?? '0',
                            ) ??
                            0)
                      : 0;
                  final subtotal = (d * n) + (d * c);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Text(
                            '₹$d',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: QaRegisterInput.hasNotes(d)
                              ? SizedBox(
                                  height: 32,
                                  child: TextFormField(
                                    key: ValueKey<String>(
                                      'close-register-note-$d',
                                    ),
                                    controller: _noteControllers[d],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onChanged: (_) => _onDenominationChanged(),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    '—',
                                    style: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: QaRegisterInput.hasCoins(d)
                              ? SizedBox(
                                  height: 32,
                                  child: TextFormField(
                                    key: ValueKey<String>(
                                      'close-register-coin-$d',
                                    ),
                                    controller: _coinControllers[d],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    onChanged: (_) => _onDenominationChanged(),
                                  ),
                                )
                              : const Center(
                                  child: Text(
                                    '—',
                                    style: TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '₹$subtotal',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: subtotal > 0
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Optional Notes
          const Text(
            'Notes & Scenario Description (Optional)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey<String>('close-register-notes'),
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. End of day cash register reconciliation',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onChanged: (_) {
              if (_statusMessage != null) {
                setState(() => _statusMessage = null);
              }
            },
          ),
          const SizedBox(height: 24),

          // Status feedback message
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _statusIsError
                      ? const Color(0xFFFFCDD2)
                      : const Color(0xFFC8E6C9),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _statusIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: _statusIsError
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _statusIsError
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          Row(
            children: <Widget>[
              ElevatedButton.icon(
                key: const ValueKey<String>('save-close-register-inputs'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  _saving ? 'Saving...' : 'Save Close Register Settings',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const ValueKey<String>('reset-close-register-inputs'),
                onPressed: _saving ? null : _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4B5563),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
