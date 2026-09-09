class ContactModel {
  const ContactModel({
    required this.id,
    required this.displayName,
    required this.publicKey,
    this.isOnline = false,
    this.lastSeen,
  });

  final String id;
  final String displayName;
  final String publicKey;
  final bool isOnline;
  final DateTime? lastSeen;

  Map<String, dynamic> toMap() => {
        'id': id,
        'display_name': displayName,
        'public_key': publicKey,
        'is_online': isOnline ? 1 : 0,
        'last_seen': lastSeen?.toIso8601String(),
      };

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      publicKey: map['public_key'] as String,
      isOnline: map['is_online'] == 1 || map['is_online'] == true,
      lastSeen: _parseDateTime(map['last_seen']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}