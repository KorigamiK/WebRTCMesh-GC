class Message {
  final String? message;
  final String type;
  final String from;

  Message({
    this.message,
    required this.type,
    required this.from,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      message: json['message'],
      type: json['type'],
      from: json['from'],
    );
  }

  @override
  String toString() {
    return 'Message{message: $message, type: $type, from: $from}';
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type,
      'from': from,
    };
  }
}
