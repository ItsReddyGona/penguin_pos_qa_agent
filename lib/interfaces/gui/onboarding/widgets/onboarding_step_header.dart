import 'package:flutter/material.dart';

/// Progress stepper header widget for the Onboarding Setup Wizard.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({super.key, required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'PenguinPOS QA Agent Setup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _buildStepCircle(0, '1', 'Target & Paths'),
              _buildStepConnector(0),
              _buildStepCircle(1, '2', 'Environment'),
              _buildStepConnector(1),
              _buildStepCircle(2, '3', 'Credentials & PIN'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int stepIndex, String numberLabel, String title) {
    final isActive = currentStep == stepIndex;
    final isDone = currentStep > stepIndex;

    final circleColor = isDone
        ? const Color(0xFF16A34A)
        : (isActive ? const Color(0xFF155EEF) : const Color(0xFFE2E8F0));
    final textColor = isActive || isDone
        ? Colors.white
        : const Color(0xFF64748B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text(
                    numberLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive || isDone
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: 12,
            color: isActive || isDone
                ? const Color(0xFF0F172A)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final isDone = currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
      ),
    );
  }
}
