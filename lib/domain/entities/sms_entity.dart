class SmsEntity {
  final String? id;
  final String? address;
  final String? body;
  final int? date;
  final int? dateSent;
  final bool? read;
  final int? type;

  SmsEntity({
    this.id,
    this.address,
    this.body,
    this.date,
    this.dateSent,
    this.read,
    this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'body': body,
      'date': date,
      'dateSent': dateSent,
      'read': read,
      'type': type,
    };
  }
}
