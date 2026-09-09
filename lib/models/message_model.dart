class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    required this.status,
    this.isRecalled = false,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String status;
  final bool isRecalled;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'status': status,
        'is_recalled': isRecalled ? 1 : 0,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final rawTimestamp = map['timestamp'];
    final timestamp = rawTimestamp is int
      ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp, isUtc: true)
        : DateTime.parse(rawTimestamp.toString());
    return MessageModel(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      content: map['content'] as String,
      timestamp: timestamp,
      status: map['status'] as String,
      isRecalled: map['is_recalled'] == 1 || map['is_recalled'] == true,
    );
  }
}