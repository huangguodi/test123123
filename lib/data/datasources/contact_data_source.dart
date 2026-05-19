import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/contact_entity.dart';

class ContactDataSource {
  Future<List<ContactEntity>> getContacts() async {
    if (await Permission.contacts.isGranted) {
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      return contacts.map((c) => ContactEntity(
        displayName: c.displayName,
        phones: c.phones.map((p) => p.number).toList(),
        emails: c.emails.map((e) => e.address).toList(),
      )).toList();
    }
    return [];
  }
}
