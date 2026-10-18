enum MediaKind { none, image, video, gif }

class ChatMessage {
  final String id;
  final String sender;
  String text;
  final bool isMe;
  final String time;
  final DateTime timestamp;
  final MediaKind mediaType;
  final bool isSOS;
  final String? mediaPath;
  final bool isEncrypted;
  bool isEdited;
  Map<String, String> reactions;
  final int hops;
  final int viewLimit; // 0 = unlimited, 1 = view once, 2 = view twice
  int viewsLeft;
  bool isOpened;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.isMe,
    required this.time,
    DateTime? timestamp,
    this.mediaType = MediaKind.none,
    this.isSOS = false,
    this.mediaPath,
    this.isEncrypted = true,
    this.isEdited = false,
    Map<String, String>? reactions,
    this.hops = 1,
    this.viewLimit = 0,
    int? viewsLeft,
    this.isOpened = false,
  })  : timestamp = timestamp ?? DateTime.now(),
        reactions = reactions ?? {},
        viewsLeft = viewsLeft ?? viewLimit;
}