class ChatMessage {
  final bool isUser;
  final String text;
  final DateTime? timestamp;

  ChatMessage({
    required this.isUser,
    required this.text,
    this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      isUser: json['isUser'] ?? false,
      text: json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isUser': isUser,
      'text': text,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}
