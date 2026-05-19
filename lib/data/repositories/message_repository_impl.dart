import '../datasources/sms_data_source.dart';
import '../../domain/entities/sms_entity.dart';
import '../../domain/repositories/message_repository.dart';

class MessageRepositoryImpl implements IMessageRepository {
  final SmsDataSource _dataSource;

  MessageRepositoryImpl(this._dataSource);

  @override
  Future<List<SmsEntity>> getSmsMessages() => _dataSource.getSmsMessages();
}
