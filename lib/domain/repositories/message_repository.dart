import '../entities/sms_entity.dart';

abstract class IMessageRepository {
  Future<List<SmsEntity>> getSmsMessages();
}
