import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String itemId;
  final String itemTitle;
  final String otherUserName;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.itemId,
    required this.itemTitle,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  late String chatRoomId;

  @override
  void initState() {
    super.initState();

    if (currentUser == null) {
      // ❗ instead of crash, just navigate back safely
      Future.microtask(() {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    final ids = [currentUser!.uid, widget.otherUserId]..sort();
    chatRoomId = "${widget.itemId}_${ids[0]}_${ids[1]}";
  }

  // 📤 SEND MESSAGE
  Future<void> sendMessage() async {
    if (_controller.text.trim().isEmpty || currentUser == null) return;

    final text = _controller.text.trim();
    _controller.clear();

    final chatRef = _firestore.collection('chats').doc(chatRoomId);
    final now = FieldValue.serverTimestamp();

    try {
      await chatRef.set({
        "participants": [currentUser!.uid, widget.otherUserId],
        "itemId": widget.itemId,
        "itemTitle": widget.itemTitle,
        "lastMessage": text,
        "lastMessageTime": now,
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        "text": text,
        "senderId": currentUser!.uid,
        "senderName": currentUser!.email ?? "User",
        "timestamp": now,
      });

      // ⬇ safer scroll
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to send message")));
    }
  }

  Widget buildMessage(Map<String, dynamic> msg) {
    final isMe = msg["senderId"] == currentUser?.uid;

    final timestamp = msg["timestamp"] as Timestamp?;
    final time = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : "";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              msg["text"] ?? "",
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              widget.itemTitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy("timestamp", descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading chat"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No messages yet",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: docs.length,

                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    return buildMessage(data);
                  },
                );
              },
            ),
          ),

          // ✍ INPUT BOX
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type message...",
                      border: InputBorder.none,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
