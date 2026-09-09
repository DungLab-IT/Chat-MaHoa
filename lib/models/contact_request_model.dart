class ContactRequestModel {
  const ContactRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.displayName,
    required this.publicKey,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String displayName;
  final String publicKey;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'display_name': displayName,
        'public_key': publicKey,
        'status': status,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory ContactRequestModel.fromMap(Map<String, dynamic> map) => ContactRequestModel(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        receiverId: map['receiver_id'] as String,
        displayName: map['display_name'] as String,
        publicKey: map['public_key'] as String,
        status: map['status'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
      );
}