/// Removes known credentials from user-visible errors, logs, and reports.
///
/// Callers must pass only values already held in their local execution scope;
/// this utility never stores, serializes, or emits a secret itself.
String redactSecrets(String value, Iterable<String?> secrets) {
  var redacted = value;
  final candidates =
      secrets
          .whereType<String>()
          .map((secret) => secret.trim())
          .where((secret) => secret.isNotEmpty)
          .toSet()
          .toList()
        ..sort((left, right) => right.length.compareTo(left.length));

  for (final secret in candidates) {
    redacted = redacted.replaceAll(secret, '[REDACTED]');
  }
  return redacted;
}
