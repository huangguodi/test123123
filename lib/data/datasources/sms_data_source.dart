import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/sms_entity.dart';

class SmsDataSource {
  final SmsQuery _query = SmsQuery();

  Future<List<SmsEntity>> getSmsMessages() async {
    if (await Permission.sms.isGranted) {
      final List<SmsMessage> messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      );

      return messages.map((msg) => SmsEntity(
        address: msg.address ?? '',
        body: msg.body ?? '',
        date: msg.date?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        type: msg.kind == SmsMessageKind.received ? 1 : 2,
      )).toList();
    }
    return [];
  }
}
