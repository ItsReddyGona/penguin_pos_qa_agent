import 'package:penguin_pos_qa_agent/automation/core/driver.dart';
import 'package:penguin_pos_qa_agent/automation/order/order_state_snapshot.dart';

/// Reads only the fields needed while waiting for one scan/add-to-cart
/// operation. Older PenguinPOS builds transparently use the full snapshot.
extension DriverOrderOperationQuery on Driver {
  Future<OrderStateSnapshot?> queryOrderOperation({
    Duration timeout = const Duration(milliseconds: 700),
  }) async {
    final compact = OrderStateSnapshot.fromResponse(
      await requestData('qa_order_operation', timeout: timeout),
    );
    return compact ?? queryOrderState(timeout: timeout);
  }
}
