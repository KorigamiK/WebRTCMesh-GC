class Message {
  final String sender;
  final String text;
  final bool isMe;

  Message({
    required this.sender,
    required this.text,
    required this.isMe,
  });

  Message.fromJson(Map<String, dynamic> json)
      : sender = json['sender'],
        text = json['text'],
        isMe = false;

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'text': text,
      };
}
