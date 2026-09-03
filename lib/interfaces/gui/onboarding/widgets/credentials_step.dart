import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Step 3 Widget: Login Credentials & Idle Timeout PIN Configuration.
class CredentialsStep extends StatefulWidget {
  const CredentialsStep({
    super.key,
    required this.loginIdController,
    required this.passwordController,
    required this.unlockPinController,
  });

  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final TextEditingController unlockPinController;

  @override
  State<CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<CredentialsStep> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Credentials & Security PIN',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure default credentials (10-digit phone number) and 4-digit unlock PIN.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),

          // User Login ID / Phone Field (10 Digits Max)
          TextField(
            controller: widget.loginIdController,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile Phone Number (10 Digits)',
              hintText: 'e.g. 9876543210',
              helperText: 'Must be exactly 10 numeric digits',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          // User Password Field with Eye Visibility Toggle
          TextField(
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Account Password',
              hintText: 'Enter account password',
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Lock Screen Unlock PIN Field (4 Digits Max)
          TextField(
            controller: widget.unlockPinController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              labelText: 'Idle Timeout Screen Unlock PIN (4 Digits)',
              hintText: 'e.g. 1234',
              helperText: 'Must be exactly 4 numeric digits',
              prefixIcon: Icon(Icons.pin_outlined, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
