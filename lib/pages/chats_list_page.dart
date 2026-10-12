import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class ChatsListPage extends StatelessWidget {
  const ChatsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Chats")),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where("participants", arrayContains: user.uid)
            .orderBy("lastMessageTime", descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading chats"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return const Center(child: Text("No conversations yet"));
          }

          return ListView.builder(
            itemCount: chats.length,

            itemBuilder: (context, index) {
              final doc = chats[index];
              final data = doc.data() as Map<String, dynamic>;

              final participants = List<String>.from(
                data["participants"] ?? [],
              );

              final currentUserId = user.uid;

              final otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => "",
              );

              final itemTitle = data["itemTitle"] ?? "Item";
              final lastMessage = data["lastMessage"] ?? "";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      itemTitle.isNotEmpty ? itemTitle[0].toUpperCase() : "C",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  title: Text(
                    itemTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  trailing: Text(
                    formatTime(data["lastMessageTime"]),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),

                  onTap: () {
                    if (otherUserId.isEmpty) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          itemId: data["itemId"] ?? "",
                          itemTitle: itemTitle,
                          otherUserId: otherUserId,
                          otherUserName: "User", // later upgrade
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ⏰ TIME FORMATTER
  String formatTime(dynamic time) {
    if (time == null) return "";

    try {
      final dt = (time as Timestamp).toDate();

      String hour = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');

      return "$hour:$min";
    } catch (e) {
      return "";
    }
  }
}
