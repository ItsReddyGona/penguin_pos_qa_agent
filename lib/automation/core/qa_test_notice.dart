/// A safe, short status message displayed by the QA-only overlay in PenguinPOS.
///
/// This is intentionally presentation-neutral: the runner owns *when* a notice
/// is shown, while the target app owns its layout and user-dismiss behaviour.
enum QaTestNoticeSeverity { info, warning, error, success }

/// Controls how much test-progress information is mirrored into PenguinPOS.
/// The default keeps the target screen quiet unless human attention is useful.
enum QaTestNoticeDisplayMode {
  all,
  milestonesAndErrors,
  warningsAndErrors,
  errorsOnly,
  never;

  bool shouldShow(QaTestNoticeSeverity severity, {bool isMilestone = false}) =>
      switch (this) {
        QaTestNoticeDisplayMode.all => true,
        QaTestNoticeDisplayMode.milestonesAndErrors =>
          isMilestone ||
              severity == QaTestNoticeSeverity.warning ||
              severity == QaTestNoticeSeverity.error,
        QaTestNoticeDisplayMode.warningsAndErrors =>
          severity == QaTestNoticeSeverity.warning ||
              severity == QaTestNoticeSeverity.error,
        QaTestNoticeDisplayMode.errorsOnly =>
          severity == QaTestNoticeSeverity.error,
        QaTestNoticeDisplayMode.never => false,
      };

  String get label => switch (this) {
    QaTestNoticeDisplayMode.all => 'All',
    QaTestNoticeDisplayMode.milestonesAndErrors =>
      'Milestones, warnings & errors',
    QaTestNoticeDisplayMode.warningsAndErrors => 'Warnings & errors',
    QaTestNoticeDisplayMode.errorsOnly => 'Errors only',
    QaTestNoticeDisplayMode.never => 'Never',
  };
}

class QaTestNotice {
  factory QaTestNotice({
    required QaTestNoticeSeverity severity,
    required String title,
    required String message,
  }) {
    return QaTestNotice._(
      severity: severity,
      title: _safeText(title, maxLength: 120),
      message: _safeText(message, maxLength: 500),
    );
  }

  const QaTestNotice._({
    required this.severity,
    required this.title,
    required this.message,
  });

  final QaTestNoticeSeverity severity;
  final String title;
  final String message;

  Map<String, String> toJson() => <String, String>{
    'type': 'qa_notice',
    'severity': severity.name,
    'title': title,
    'message': message,
  };

  static String _safeText(String value, {required int maxLength}) {
    final normalized = value
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 1)}…';
  }
}

/// Lightweight container for block execution notice metadata.
class StepNotice {
  const StepNotice(this.title, this.message, {this.isMilestone = false});

  final String title;
  final String message;
  final bool isMilestone;
}
