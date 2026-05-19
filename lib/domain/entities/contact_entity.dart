class ContactEntity {
  final String displayName;
  final List<String> phones;
  final List<String> emails;

  ContactEntity({
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phones': phones,
      'emails': emails,
    };
  }
}
