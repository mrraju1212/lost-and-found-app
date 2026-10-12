import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_item_screen.dart';
import 'Item _Details.dart';
import 'chats_list_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedTab = "All";
  String selectedCategory = "All Categories";

  bool isAdmin = false;

  final List<String> categories = [
    "All Categories",
    "Wallet",
    "Phone",
    "Keys",
    "ID Card",
    "Bag",
    "Watch",
    "Jewelry",
    "Electronics",
    "Clothing",
    "Other",
  ];

  // 🧪 DUMMY DATA
  final List<Map<String, dynamic>> dummyItems = [
    {
      "id": "1",
      "title": "Lost Black Wallet",
      "type": "lost",
      "description": "Black leather wallet with cards.",
      "location": "Central Park",
      "category": "Wallet",
      "user": "Sarah",
      "userId": "user1",
      "date": "4/8/2026",
      "imageUrl":
          "https://images.unsplash.com/photo-1627123424574-724758594e93?w=800",
    },
    {
      "id": "2",
      "title": "Found iPhone",
      "type": "found",
      "description": "Found near station.",
      "location": "Times Square",
      "category": "Phone",
      "user": "John",
      "userId": "user2",
      "date": "4/7/2026",
      "imageUrl":
          "https://images.unsplash.com/photo-1592750475338-74b7b21085ab?w=800",
    },
  ];

  @override
  void initState() {
    super.initState();
    loadUserRole();
  }

  // ✅ FIXED ROLE LOADER
  Future<void> loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // ✅ If user document doesn't exist
      if (!doc.exists) {
        debugPrint("User document does not exist");

        // Optional: create user document automatically
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email ?? '',
          'role': 'user',
          'createdAt': Timestamp.now(),
        });

        setState(() {
          isAdmin = false;
        });

        return;
      }

      final data = doc.data();

      if (data == null) {
        setState(() {
          isAdmin = false;
        });

        return;
      }

      setState(() {
        isAdmin = data['role'] == 'admin';
      });
    } catch (e) {
      debugPrint("Role loading error: $e");

      setState(() {
        isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),

      appBar: AppBar(
        title: const Text("Lost & Found"),

        actions: [
          // 💬 CHAT
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatsListPage()),
              );
            },
          ),

          // 👤 PROFILE
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),

          // 🛡 ADMIN
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.pushNamed(context, '/admin');
              },
            ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            // 🔍 SEARCH + CATEGORY
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),

                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),

                      filled: true,
                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                DropdownButton<String>(
                  value: selectedCategory,

                  items: categories.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e));
                  }).toList(),

                  onChanged: (val) {
                    setState(() {
                      selectedCategory = val!;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 🔘 FILTERS + POST BUTTON
            Row(
              children: [
                filter("All"),
                filter("Lost"),
                filter("Found"),

                const Spacer(),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PostItemScreen()),
                    );
                  },

                  child: const Text("Post"),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 📡 ITEMS
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("items")
                    .where("status", isEqualTo: "approved")
                    .snapshots(),

                builder: (context, snapshot) {
                  List<Map<String, dynamic>> itemsToShow = [];

                  // 🔥 FIRESTORE ITEMS
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    itemsToShow = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return {"id": doc.id, ...data};
                    }).toList();
                  }
                  // 🧪 DUMMY ITEMS
                  else {
                    itemsToShow = dummyItems;
                  }

                  // 🔎 FILTER
                  final filtered = itemsToShow.where((item) {
                    final search = searchController.text.toLowerCase();

                    final matchesSearch =
                        (item["title"] ?? "").toString().toLowerCase().contains(
                          search,
                        ) ||
                        (item["description"] ?? "")
                            .toString()
                            .toLowerCase()
                            .contains(search);

                    final matchesTab = selectedTab == "All"
                        ? true
                        : (item["type"] ?? "").toString().toLowerCase() ==
                              selectedTab.toLowerCase();

                    final matchesCategory = selectedCategory == "All Categories"
                        ? true
                        : item["category"] == selectedCategory;

                    return matchesSearch && matchesTab && matchesCategory;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text("No approved items found"));
                  }

                  return GridView.builder(
                    itemCount: filtered.length,

                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.75,
                    ),

                    itemBuilder: (_, i) {
                      final item = filtered[i];

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemDetailsPage(item: item),
                            ),
                          );
                        },

                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              // 🖼 IMAGE
                              Expanded(
                                flex: 5,

                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),

                                  child: Image.network(
                                    item["imageUrl"] ?? "",

                                    width: double.infinity,
                                    fit: BoxFit.cover,

                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],

                                        child: const Center(
                                          child: Icon(
                                            Icons.image_not_supported,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // 📝 CONTENT
                              Expanded(
                                flex: 6,

                                child: Padding(
                                  padding: const EdgeInsets.all(10),

                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        item["title"] ?? "",

                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        item["description"] ?? "",

                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,

                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),

                                      const Spacer(),

                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Colors.grey,
                                          ),

                                          const SizedBox(width: 4),

                                          Expanded(
                                            child: Text(
                                              item["location"] ?? "",

                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,

                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),

                                        decoration: BoxDecoration(
                                          color:
                                              (item["type"] ?? "lost") == "lost"
                                              ? Colors.red
                                              : Colors.green,

                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),

                                        child: Text(
                                          (item["type"] ?? "")
                                              .toString()
                                              .toUpperCase(),

                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔘 FILTER BUTTON
  Widget filter(String title) {
    final selected = selectedTab == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = title;
        });
      },

      child: Container(
        margin: const EdgeInsets.only(right: 8),

        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,

          borderRadius: BorderRadius.circular(8),
        ),

        child: Text(
          title,

          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
