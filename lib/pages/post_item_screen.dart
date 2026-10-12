import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class PostItemScreen extends StatefulWidget {
  const PostItemScreen({super.key});

  @override
  State<PostItemScreen> createState() => _PostItemScreenState();
}

class _PostItemScreenState extends State<PostItemScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  bool isLoading = false;

  XFile? _imageFile;
  Uint8List? webImage;

  String _type = "lost";
  String _category = "Phone";

  final List<String> categories = [
    "Phone",
    "Wallet",
    "Keys",
    "ID Card",
    "Bag",
    "Watch",
    "Jewelry",
    "Electronics",
    "Clothing",
    "Other",
  ];

  @override
  void dispose() {
    titleController.dispose();
    descController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // 📸 PICK IMAGE
  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked != null) {
        _imageFile = picked;

        if (kIsWeb) {
          webImage = await picked.readAsBytes();
        }

        setState(() {});
      }
    } catch (e) {
      showMessage("Image pick failed: $e");
    }
  }

  // ☁️ CLOUDINARY IMAGE UPLOAD
  Future<String> uploadImageToCloudinary() async {
    try {
      String cloudName = "dluojlr2y";
      String uploadPreset = "lostfoundapp";

      var uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
      );

      var request = http.MultipartRequest("POST", uri);

      request.fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            webImage!,
            filename: 'upload.jpg',
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', _imageFile!.path),
        );
      }

      var response = await request.send();

      var responseData = await response.stream.bytesToString();

      var data = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return data["secure_url"];
      } else {
        throw Exception(data.toString());
      }
    } catch (e) {
      throw Exception("Cloudinary Upload Failed: $e");
    }
  }

  // 📤 POST ITEM
  Future<void> postItem() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      showMessage("Please select an image");
      return;
    }

    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage("User not logged in");
        return;
      }

      // ☁️ Upload image to Cloudinary
      String imageUrl = await uploadImageToCloudinary();

      // 🔥 Save item in Firestore
      await FirebaseFirestore.instance.collection("items").add({
        "title": titleController.text.trim(),
        "description": descController.text.trim(),
        "location": locationController.text.trim(),
        "category": _category,
        "type": _type,
        "imageUrl": imageUrl,
        "userId": user.uid,
        "userEmail": user.email ?? "",
        "userName": user.displayName ?? "User",
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      showMessage("Item posted successfully");

      Navigator.pop(context);
    } catch (e) {
      showMessage("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),

      appBar: AppBar(
        title: const Text("Post Item"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          child: Padding(
            padding: const EdgeInsets.all(18),

            child: Form(
              key: _formKey,

              child: Column(
                children: [
                  const Text(
                    "Create a Listing",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // 📸 IMAGE PICKER
                  GestureDetector(
                    onTap: pickImage,

                    child: Container(
                      height: 180,
                      width: double.infinity,

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blueAccent),
                      ),

                      child: _imageFile == null
                          ? const Center(child: Text("Click to Upload Image"))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),

                              child: kIsWeb
                                  ? Image.memory(webImage!, fit: BoxFit.cover)
                                  : Image.network(
                                      _imageFile!.path,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // TYPE
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          title: const Text("Lost"),
                          value: "lost",
                          groupValue: _type,
                          onChanged: (value) {
                            setState(() => _type = value!);
                          },
                        ),
                      ),

                      Expanded(
                        child: RadioListTile(
                          title: const Text("Found"),
                          value: "found",
                          groupValue: _type,
                          onChanged: (value) {
                            setState(() => _type = value!);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // TITLE
                  TextFormField(
                    controller: titleController,

                    decoration: const InputDecoration(
                      labelText: "Title",
                      border: OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter title";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // DESCRIPTION
                  TextFormField(
                    controller: descController,
                    maxLines: 4,

                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter description";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // LOCATION
                  TextFormField(
                    controller: locationController,

                    decoration: const InputDecoration(
                      labelText: "Location",
                      border: OutlineInputBorder(),
                    ),

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter location";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  // CATEGORY
                  DropdownButtonFormField<String>(
                    value: _category,

                    items: categories.map((item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),

                    onChanged: (value) {
                      setState(() => _category = value!);
                    },

                    decoration: const InputDecoration(
                      labelText: "Category",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),

                          child: const Text("Cancel"),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : postItem,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),

                          child: isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,

                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Post Item",
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
