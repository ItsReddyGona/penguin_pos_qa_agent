/// Stable widget keys forming the Register QA contract with PenguinPOS.
abstract final class PenguinPosRegisterKeys {
  static const registerScreen = 'register.screen';
  static const inputOpeningFloat = 'register.input.opening_float';
  static const inputClosingFloat = 'register.input.closing_float';
  static const registerSubmit = 'register.submit';
  static const errorDialogOk = 'error_dialog.ok';
  static const homeRegisterTab = 'home.tab.register';

  // Payment Summary - Card & UPI Gateway Fields
  static const inputPinelabsCardAmount = 'register.input.pinelabs_card.amount';
  static const inputPinelabsCardCount = 'register.input.pinelabs_card.count';
  static const inputPinelabsUpiAmount = 'register.input.pinelabs_upi.amount';
  static const inputPinelabsUpiCount = 'register.input.pinelabs_upi.count';

  static const inputRazorpayCardAmount = 'register.input.razorpay_card.amount';
  static const inputRazorpayCardCount = 'register.input.razorpay_card.count';
  static const inputRazorpayUpiAmount = 'register.input.razorpay_upi.amount';
  static const inputRazorpayUpiCount = 'register.input.razorpay_upi.count';

  static const inputPaytmCardAmount = 'register.input.paytm_card.amount';
  static const inputPaytmCardCount = 'register.input.paytm_card.count';
  static const inputPaytmUpiAmount = 'register.input.paytm_upi.amount';
  static const inputPaytmUpiCount = 'register.input.paytm_upi.count';

  static const inputIciciOrangeCardAmount =
      'register.input.icici_orange_card.amount';
  static const inputIciciOrangeCardCount =
      'register.input.icici_orange_card.count';
  static const inputIciciOrangeUpiAmount =
      'register.input.icici_orange_upi.amount';
  static const inputIciciOrangeUpiCount =
      'register.input.icici_orange_upi.count';

  static const inputCardAmount = 'register.input.card.amount';
  static const inputCardCount = 'register.input.card.count';
  static const inputUpiAmount = 'register.input.upi.amount';
  static const inputUpiCount = 'register.input.upi.count';

  // Cash Denomination Tables (Notes & Coins)
  static String cashNotes(int denom) => 'register.cash.$denom.notes';
  static String cashCoins(int denom) => 'register.cash.$denom.coins';
  static String cashAmount(int denom) => 'register.cash.$denom.amount';

  // Total Cash Display
  static const cashTotal = 'register.cash.total';

  // Custom Keypad
  static const numpadInput = 'register.numpad.input';
  static String numpadDigit(String n) => 'register.numpad.digit.$n';
  static const numpadDecimal = 'register.numpad.digit..';
  static const numpadDoubleZero = 'register.numpad.digit.00';
  static const numpadBackspace = 'register.numpad.backspace';
  static const numpadClear = 'register.numpad.clear';
  static const numpadEnter = 'register.numpad.enter';
}
