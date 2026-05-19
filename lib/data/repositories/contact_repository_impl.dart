import '../datasources/contact_data_source.dart';
import '../../domain/entities/contact_entity.dart';
import '../../domain/repositories/contact_repository.dart';

class ContactRepositoryImpl implements IContactRepository {
  final ContactDataSource _dataSource;

  ContactRepositoryImpl(this._dataSource);

  @override
  Future<List<ContactEntity>> getContacts() => _dataSource.getContacts();
}
