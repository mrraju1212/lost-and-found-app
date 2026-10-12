import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // 🔄 UPDATE STATUS
  Future<void> updateStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('items').doc(id).update({
      "status": status,
    });
  }

  // 🗑 DELETE ITEM
  Future<void> deleteItem(String id) async {
    await FirebaseFirestore.instance.collection('items').doc(id).delete();
  }

  // ⚠ DELETE CONFIRM
  void confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          TextButton(
            onPressed: () {
              deleteItem(id);
              Navigator.pop(context);
            },

            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 📦 ITEM LIST
  Widget buildItemList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('status', isEqualTo: status)
          .snapshots(),

      builder: (context, snapshot) {
        // 🔴 FIRESTORE ERROR
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Firestore Error:\n${snapshot.error}",
              textAlign: TextAlign.center,
            ),
          );
        }

        // ⏳ LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 📭 EMPTY
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $status items"));
        }

        final items = snapshot.data!.docs;

        // 🔽 SORT MANUALLY
        items.sort((a, b) {
          final aTime =
              (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

          final bTime =
              (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;

          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          itemCount: items.length,

          itemBuilder: (_, i) {
            final doc = items[i];

            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(10),

              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),

                  child: Image.network(
                    data['imageUrl'] ?? "",

                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,

                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],

                        child: const Icon(Icons.image),
                      );
                    },
                  ),
                ),

                title: Text(data['title'] ?? "No Title"),

                subtitle: Text(
                  data['description'] ?? "",

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                trailing: Wrap(
                  spacing: 6,

                  children: [
                    // ✅ APPROVE
                    if (status != "approved")
                      ElevatedButton(
                        onPressed: () {
                          updateStatus(doc.id, "approved");
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),

                        child: const Text("Approve"),
                      ),

                    // ❌ REJECT
                    if (status != "rejected")
                      ElevatedButton(
                        onPressed: () {
                          updateStatus(doc.id, "rejected");
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),

                        child: const Text("Reject"),
                      ),

                    // 🗑 DELETE
                    IconButton(
                      onPressed: () {
                        confirmDelete(context, doc.id);
                      },

                      icon: const Icon(Icons.delete, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 📊 STATS
  Widget buildStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('items').snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        final docs = snapshot.data!.docs;

        int total = docs.length;

        int pending = docs
            .where(
              (e) => (e.data() as Map<String, dynamic>)['status'] == 'pending',
            )
            .length;

        int approved = docs
            .where(
              (e) => (e.data() as Map<String, dynamic>)['status'] == 'approved',
            )
            .length;

        int rejected = docs
            .where(
              (e) => (e.data() as Map<String, dynamic>)['status'] == 'rejected',
            )
            .length;

        return Row(
          children: [
            statCard("Total", total.toString(), Colors.blue),

            statCard("Pending", pending.toString(), Colors.orange),

            statCard("Approved", approved.toString(), Colors.green),

            statCard("Rejected", rejected.toString(), Colors.red),
          ],
        );
      },
    );
  }

  // 📦 STAT CARD
  Widget statCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),

          child: Column(
            children: [
              Text(title),

              const SizedBox(height: 5),

              Text(
                value,

                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),

        bottom: TabBar(
          controller: _tabController,

          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Approved"),
            Tab(text: "Rejected"),
          ],
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),

            child: buildStats(),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: TabBarView(
              controller: _tabController,

              children: [
                buildItemList("pending"),
                buildItemList("approved"),
                buildItemList("rejected"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
