import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/domain/profiles/qa_profile.dart';
import 'package:penguin_pos_qa_agent/domain/test_cases/login_test_case.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/settings/widgets/settings_form_card.dart';

typedef LoginCasesLoader =
    Future<List<LoginTestCaseDefinition>> Function(String profileId);
typedef LoginCasesSaver =
    Future<void> Function(
      String profileId,
      List<LoginTestCaseDefinition> cases,
    );

const _executableLoginOutcomes = <LoginExpectedResult>[
  LoginExpectedResult.authenticationRejected,
  LoginExpectedResult.requiredFieldValidation,
  LoginExpectedResult.successfulLogin,
];

/// Profile-scoped editor for the data-driven Login test suite.
class InputsCredentialsSettingsTab extends StatefulWidget {
  const InputsCredentialsSettingsTab({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.loadCases,
    required this.saveCases,
    required this.onProfileChanged,
    this.showProfileSelector = true,
  });

  final List<QaProfile> profiles;
  final QaProfile selectedProfile;
  final LoginCasesLoader loadCases;
  final LoginCasesSaver saveCases;
  final ValueChanged<QaProfile> onProfileChanged;
  final bool showProfileSelector;

  @override
  State<InputsCredentialsSettingsTab> createState() =>
      _InputsCredentialsSettingsTabState();
}

class _InputsCredentialsSettingsTabState
    extends State<InputsCredentialsSettingsTab> {
  final _formKey = GlobalKey<FormState>();
  List<LoginTestCaseDefinition> _cases = <LoginTestCaseDefinition>[];
  final Set<String> _visiblePasswords = <String>{};
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  int _nextLocalId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant InputsCredentialsSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfile.id != widget.selectedProfile.id) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cases = await widget.loadCases(widget.selectedProfile.id);
      if (!mounted) return;
      setState(() {
        _cases = List<LoginTestCaseDefinition>.from(cases);
        _visiblePasswords.clear();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load login test cases: $error';
      });
    }
  }

  void _addCase() {
    final sequence = _cases.length + 1;
    final id =
        'login-case-${DateTime.now().microsecondsSinceEpoch}-${_nextLocalId++}';
    setState(() {
      _cases = <LoginTestCaseDefinition>[
        ..._cases,
        LoginTestCaseDefinition(
          id: id,
          name: 'Login test $sequence',
          expectedResult: LoginExpectedResult.requiredFieldValidation,
        ),
      ];
    });
  }

  void _duplicateCase(int index) {
    final source = _cases[index];
    final copy = _copyCase(
      source,
      id: 'login-case-${DateTime.now().microsecondsSinceEpoch}-${_nextLocalId++}',
      name: '${source.name} copy',
    );
    setState(() {
      _cases = List<LoginTestCaseDefinition>.from(_cases)
        ..insert(index + 1, copy);
    });
  }

  void _removeCase(int index) {
    final removed = _cases[index];
    setState(() {
      _cases = List<LoginTestCaseDefinition>.from(_cases)..removeAt(index);
      _visiblePasswords.remove(removed.id);
    });
  }

  void _replaceCase(int index, LoginTestCaseDefinition value) {
    setState(() {
      _cases = List<LoginTestCaseDefinition>.from(_cases)..[index] = value;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final reordered = List<LoginTestCaseDefinition>.from(_cases);
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);
      _cases = reordered;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.saveCases(widget.selectedProfile.id, _cases);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${_cases.length} login test case${_cases.length == 1 ? '' : 's'} '
            'for ${widget.selectedProfile.label}.',
          ),
          backgroundColor: const Color(0xFF658A7A),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save login test cases: $error'),
          backgroundColor: const Color(0xFF9A4D45),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.showProfileSelector) ...<Widget>[
          const Text(
            'Inputs & Credentials',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C302E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Define the Login test cases that Manual and AI runs will execute. '
            'Empty credential fields are preserved as intentional test inputs.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF787A76)),
          ),
          const SizedBox(height: 24),
          SettingsFormCard(
            children: <Widget>[
              const Text(
                'Target Profile / Environment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<QaProfile>(
                key: ValueKey<String>(widget.selectedProfile.id),
                initialValue: widget.selectedProfile,
                isDense: true,
                decoration: _fieldDecoration(),
                items: widget.profiles
                    .map(
                      (profile) => DropdownMenuItem<QaProfile>(
                        value: profile,
                        child: Text(profile.label),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (profile) {
                        if (profile != null) widget.onProfileChanged(profile);
                      },
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_loadError != null)
          _LoadError(message: _loadError!, onRetry: _load)
        else
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Login Test Cases',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C302E),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey<String>('add-login-test-case'),
                      onPressed: _saving ? null : _addCase,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add test case'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_cases.isEmpty)
                  _EmptyCases(onAdd: _addCase)
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _cases.length,
                    onReorderItem: _reorder,
                    itemBuilder: (context, index) {
                      final testCase = _cases[index];
                      return _LoginCaseCard(
                        key: ValueKey<String>(testCase.id),
                        index: index,
                        testCase: testCase,
                        passwordVisible: _visiblePasswords.contains(
                          testCase.id,
                        ),
                        onChanged: (value) => _replaceCase(index, value),
                        onTogglePassword: () => setState(() {
                          _toggleSet(_visiblePasswords, testCase.id);
                        }),
                        onDuplicate: () => _duplicateCase(index),
                        onRemove: () => _removeCase(index),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('save-login-test-cases'),
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
                    label: const Text('Save Login Test Cases'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LoginCaseCard extends StatelessWidget {
  const _LoginCaseCard({
    super.key,
    required this.index,
    required this.testCase,
    required this.passwordVisible,
    required this.onChanged,
    required this.onTogglePassword,
    required this.onDuplicate,
    required this.onRemove,
  });

  final int index;
  final LoginTestCaseDefinition testCase;
  final bool passwordVisible;
  final ValueChanged<LoginTestCaseDefinition> onChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            // Row 1: Drag handle + Auto-generated TC badge on left, Actions on right
            Row(
              children: <Widget>[
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: Color(0xFF787A76),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5ECE8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'TC-${(index + 1).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: Color(0xFF2C302E),
                    ),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Duplicate test case',
                  child: IconButton(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ),
                Tooltip(
                  message: 'Delete test case',
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  ),
                ),
                const SizedBox(width: 4),
                Switch.adaptive(
                  value: testCase.enabled,
                  onChanged: (value) =>
                      onChanged(_copyCase(testCase, enabled: value)),
                ),
                const Text('Enabled', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Title (Test Case Name) & Description / Requirement
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    key: ValueKey<String>('id-field-$index'),
                    initialValue: testCase.id,
                    decoration: _fieldDecoration(label: 'Test Case ID'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Test case ID is required.'
                        : null,
                    onChanged: (value) =>
                        onChanged(_copyCase(testCase, id: value.trim())),
                  ),
                ),
                const SizedBox(width: 12),
                // Title / Name
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey<String>('name-${testCase.id}'),
                    initialValue: testCase.name,
                    decoration: _fieldDecoration(label: 'Test Case Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Test case name is required.'
                        : null,
                    onChanged: (value) =>
                        onChanged(_copyCase(testCase, name: value)),
                  ),
                ),
                const SizedBox(width: 12),
                // Description
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey<String>('description-${testCase.id}'),
                    initialValue: testCase.description,
                    decoration: _fieldDecoration(label: 'Description'),
                    minLines: 2,
                    maxLines: 5,
                    onChanged: (value) =>
                        onChanged(_copyCase(testCase, description: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: Credentials (Username, Password) & Expected Result
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 1. Username (flex: 1)
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    key: ValueKey<String>('username-${testCase.id}'),
                    initialValue: testCase.username,
                    decoration: _fieldDecoration(
                      label: 'Username',
                      hint: 'Leave empty to test required validation',
                    ),
                    onChanged: (value) =>
                        onChanged(_copyCase(testCase, username: value)),
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Password (flex: 1)
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    key: ValueKey<String>('password-${testCase.id}'),
                    initialValue: testCase.password,
                    obscureText: !passwordVisible,
                    decoration: _fieldDecoration(
                      label: 'Password',
                      hint: 'Leave empty to test required validation',
                      suffixIcon: IconButton(
                        tooltip: passwordVisible
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: onTogglePassword,
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onChanged: (value) =>
                        onChanged(_copyCase(testCase, password: value)),
                  ),
                ),
                const SizedBox(width: 12),
                // 3. Expected Result (flex: 1)
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<LoginExpectedResult>(
                    key: ValueKey<String>('expected-${testCase.id}'),
                    initialValue:
                        _executableLoginOutcomes.contains(
                          testCase.expectedResult,
                        )
                        ? testCase.expectedResult
                        : null,
                    isExpanded: true,
                    decoration: _fieldDecoration(label: 'Expected Result'),
                    items: _executableLoginOutcomes
                        .map(
                          (result) => DropdownMenuItem<LoginExpectedResult>(
                            value: result,
                            child: Text(
                              _expectedResultLabel(result),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(_copyCase(testCase, expectedResult: value));
                      }
                    },
                  ),
                ),
              ],
            ),
            _CaseCompatibilityValidator(testCase: testCase),
          ],
        ),
      ),
    );
  }
}

class _CaseCompatibilityValidator extends FormField<void> {
  _CaseCompatibilityValidator({required LoginTestCaseDefinition testCase})
    : super(
        validator: (_) => _validateCase(testCase),
        builder: (state) => state.hasError
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFBA1A1A),
                    fontSize: 12,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
}

class _EmptyCases extends StatelessWidget {
  const _EmptyCases({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC7C9C4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.fact_check_outlined, color: Color(0xFF658A7A)),
          const SizedBox(height: 10),
          const Text('No Login test cases configured.'),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create the first test case'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: Color(0xFF9A4D45)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
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

void _toggleSet(Set<String> values, String value) {
  if (!values.remove(value)) values.add(value);
}

String? _validateCase(LoginTestCaseDefinition testCase) {
  if (!testCase.enabled) return null;
  final hasUsername = testCase.username.isNotEmpty;
  final hasPassword = testCase.password.isNotEmpty;
  return switch (testCase.expectedResult) {
    LoginExpectedResult.requiredFieldValidation =>
      hasUsername && hasPassword
          ? 'Required-field validation needs an empty username or password.'
          : null,
    LoginExpectedResult.authenticationRejected =>
      !hasUsername || !hasPassword
          ? 'Authentication rejection requires both username and password.'
          : null,
    LoginExpectedResult.successfulLogin =>
      !hasUsername || !hasPassword
          ? 'Successful login requires both username and password.'
          : null,
    LoginExpectedResult.idlePinRejected ||
    LoginExpectedResult.idlePinAccepted =>
      'Idle PIN outcomes are not supported yet.',
  };
}

String _expectedResultLabel(LoginExpectedResult result) => switch (result) {
  LoginExpectedResult.authenticationRejected => 'Invalid credentials',
  LoginExpectedResult.requiredFieldValidation => 'Validation error',
  LoginExpectedResult.successfulLogin => 'Successful login',
  LoginExpectedResult.idlePinRejected => 'Idle PIN rejected',
  LoginExpectedResult.idlePinAccepted => 'Idle PIN accepted',
};

LoginTestCaseDefinition _copyCase(
  LoginTestCaseDefinition source, {
  String? id,
  String? name,
  String? description,
  String? username,
  String? password,
  String? pin,
  LoginExpectedResult? expectedResult,
  bool? enabled,
}) => LoginTestCaseDefinition(
  id: id ?? source.id,
  name: name ?? source.name,
  description: description ?? source.description,
  username: username ?? source.username,
  password: password ?? source.password,
  pin: pin ?? source.pin,
  expectedResult: expectedResult ?? source.expectedResult,
  enabled: enabled ?? source.enabled,
);
