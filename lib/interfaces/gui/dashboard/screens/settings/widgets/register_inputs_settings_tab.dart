import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/profiles/qa_register_input_repository.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

class RegisterInputsSettingsTab extends StatefulWidget {
  const RegisterInputsSettingsTab({
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
  State<RegisterInputsSettingsTab> createState() =>
      _RegisterInputsSettingsTabState();
}

class _RegisterInputsSettingsTabState extends State<RegisterInputsSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  static const double _minAmount = QaRegisterInput.minAmount;
  static const double _maxAmount = QaRegisterInput.maxAmount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RegisterInputsSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfile.id != widget.selectedProfile.id) {
      _load();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
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
    final clamped = input.openingFloatAmount.clamp(_minAmount, _maxAmount);
    setState(() {
      _amountController.text = _formatAmount(clamped);
      _notesController.text = input.notes;
      _loading = false;
    });
  }

  String _formatAmount(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  void _onAmountTextChanged(String text) {
    if (_statusMessage != null) {
      setState(() => _statusMessage = null);
    }
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
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

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

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
        openingFloatAmount: parsedAmount,
        notes: _notesController.text.trim(),
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
            'Saved Register opening float: ₹${_formatAmount(parsedAmount)} for ${widget.selectedProfile.label}.';
        _statusIsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _statusMessage = 'Failed to save register inputs: $e';
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
            'Opening Float Cash Amount (₹0 – ₹5,000) *',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const ValueKey<String>('register-opening-float-amount'),
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
              hintText: 'Enter amount between 0 and 5000',
              helperText:
                  'Allowed range: ₹0 to ₹5,000. This float amount is entered during register opening.',
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
            key: const ValueKey<String>('register-notes'),
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Standard morning shift cash float',
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
                key: const ValueKey<String>('save-register-inputs'),
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
                label: Text(_saving ? 'Saving...' : 'Save Register Settings'),
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
                key: const ValueKey<String>('reset-register-inputs'),
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
