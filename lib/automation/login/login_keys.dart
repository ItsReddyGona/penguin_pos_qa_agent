/// Stable widget keys forming the login QA contract with PenguinPOS.
abstract final class PenguinPosLoginKeys {
  static const loginId = 'login.id';
  static const password = 'login.password';
  static const submit = 'login.submit';
  static const terminalContinue = 'login.terminal.continue';
  static const homeScreen = 'home.screen';
  static const logoutButton = 'logout.button';
  static const logoutConfirm = 'logout.confirm';

  // Feature-specific Snackbar & Dismissal keys
  static const loginErrorSnackBar = 'login.error_snackbar';
  static const loginErrorDismiss = 'login.error_snackbar_dismiss';
  static const terminalErrorSnackBar = 'terminal.error_snackbar';
  static const terminalErrorDismiss = 'terminal.error_snackbar_dismiss';

  // Global fallbacks
  static const authErrorSnackBar = loginErrorSnackBar;
  static const authErrorDismiss = loginErrorDismiss;
}
