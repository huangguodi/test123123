import '../entities/contact_entity.dart';

abstract class IContactRepository {
  Future<List<ContactEntity>> getContacts();
}
