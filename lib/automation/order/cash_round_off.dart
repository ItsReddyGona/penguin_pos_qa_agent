/// Calculates round-off payable amount matching POS business logic:
/// paise = totalAmount - floor(totalAmount)
/// payableAmount = paise < 0.50 ? floor(totalAmount) : ceil(totalAmount)
int calculateRoundOff(double totalAmount) {
  final int floorVal = totalAmount.floor();
  final double paise = totalAmount - floorVal;
  return paise < 0.50 ? floorVal : totalAmount.ceil();
}
