import 'dart:typed_data'; // For working with image bytes
import 'package:flutter/material.dart'; // Core Flutter widgets
import 'package:image_picker/image_picker.dart'; // For picking images from gallery/camera
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage (uploading images)
import 'package:firebase_database/firebase_database.dart'; // For Firebase Realtime Database
import 'login_page.dart'; // Import for navigating to the login page
import 'post_details_page.dart'; // Import for navigating to post details

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Firebase references for database and storage
  final DatabaseReference _postsRef = FirebaseDatabase.instance.ref('posts');
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // State variables for managing posts and loading status
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Fetch posts when the widget is initialized
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final snapshot = await _postsRef.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final tempPosts = data.entries.map((e) {
          final value = Map<String, dynamic>.from(e.value);
          return {
            'key': e.key,
            'title': value['title']?.toString() ?? 'No Title',
            'imageUrl': value['imageUrl']?.toString() ?? '',
            'githubLink': value['githubLink']?.toString() ?? '',
            'codeBlocks': List<String>.from(value['codeBlocks'] ?? []),
          };
        }).toList();
        setState(() {
          posts = tempPosts;
          isLoading = false;
        });
      } else {
        setState(() {
          posts = [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error fetching posts: $e", Colors.red);
      setState(() => isLoading = false);
    }
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error logging out: $e", Colors.red);
    }
  }

  void _showSnackBar(String message, [Color color = Colors.green]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _addNewPost() async {
    final titleController = TextEditingController();
    final githubController = TextEditingController();
    List<TextEditingController> codeControllers = [TextEditingController()];
    Uint8List? selectedImageBytes;
    String? fileExtension;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add New Post"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: githubController,
                      decoration: const InputDecoration(labelText: "GitHub Link (optional)"),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Code Blocks:"),
                        ...codeControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: "Code ${index + 1}",
                                suffixIcon: codeControllers.length > 1
                                    ? IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setDialogState(() => codeControllers.removeAt(index));
                                        },
                                      )
                                    : null,
                              ),
                              maxLines: 3,
                              minLines: 1,
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() => codeControllers.add(TextEditingController()));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Add Code Block"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setDialogState(() {
                            selectedImageBytes = bytes;
                            fileExtension = picked.name.split('.').last;
                          });
                          if (mounted) _showSnackBar("Image selected.");
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("Select Image"),
                    ),
                    const SizedBox(height: 10),
                    if (selectedImageBytes != null)
                      const Text("Image selected.", style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final codeList = codeControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                    if (title.isEmpty || selectedImageBytes == null || codeList.isEmpty) {
                      if (mounted) _showSnackBar("Title, image, and at least one code block are required.", Colors.red);
                      return;
                    }
                    if (mounted) Navigator.pop(context);
                    _showSnackBar("Uploading post...", Colors.blue);
                    try {
                      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
                      final ref = _storage.ref().child('uploads/$fileName.$fileExtension');
                      await ref.putData(selectedImageBytes!);
                      final imageUrl = await ref.getDownloadURL();
                      await _postsRef.push().set({
                        'title': title,
                        'imageUrl': imageUrl,
                        'githubLink': githubController.text.trim(),
                        'codeBlocks': codeList,
                      });
                      _fetchPosts();
                      if (mounted) _showSnackBar("Post uploaded successfully.");
                    } catch (e) {
                      if (mounted) _showSnackBar("Error uploading post: $e", Colors.red);
                    }
                  },
                  child: const Text("Upload"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editPost(
    String postKey,
    String currentTitle,
    String currentImageUrl,
    String currentGithubLink,
    List<String> currentCodeBlocks,
  ) async {
    final titleController = TextEditingController(text: currentTitle);
    final githubController = TextEditingController(text: currentGithubLink);
    List<TextEditingController> codeControllers =
        currentCodeBlocks.map((c) => TextEditingController(text: c)).toList();
    if (codeControllers.isEmpty) codeControllers.add(TextEditingController());
    Uint8List? selectedImageBytes;
    String? fileExtension;
    String newImageUrl = currentImageUrl;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Post"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: githubController,
                      decoration: const InputDecoration(labelText: "GitHub Link (optional)"),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Code Blocks:"),
                        ...codeControllers.asMap().entries.map((entry) {
                          int index = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: "Code ${index + 1}",
                                suffixIcon: codeControllers.length > 1
                                    ? IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () {
                                          setDialogState(() => codeControllers.removeAt(index));
                                        },
                                      )
                                    : null,
                              ),
                              maxLines: 3,
                              minLines: 1,
                            ),
                          );
                        }),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setDialogState(() => codeControllers.add(TextEditingController()));
                            },
                            icon: const Icon(Icons.add),
                            label: const Text("Add Code Block"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (selectedImageBytes != null)
                      Image.memory(selectedImageBytes!, width: 100, height: 100, fit: BoxFit.cover),
                    const SizedBox(height: 5),
                    Text(selectedImageBytes != null ? "New image selected" : "Current image"),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setDialogState(() {
                            selectedImageBytes = bytes;
                            fileExtension = picked.name.split('.').last;
                          });
                          if (mounted) _showSnackBar("New image selected.");
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("Change Image"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final codeList = codeControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                    if (title.isEmpty || codeList.isEmpty) {
                      if (mounted) _showSnackBar("Title and at least one code block are required.", Colors.red);
                      return;
                    }
                    if (mounted) Navigator.pop(context);
                    _showSnackBar("Updating post...", Colors.blue);
                    try {
                      if (selectedImageBytes != null) {
                        if (currentImageUrl.isNotEmpty) {
                          try {
                            final oldRef = _storage.refFromURL(currentImageUrl);
                            await oldRef.delete();
                          } catch (_) {}
                        }
                        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
                        final ref = _storage.ref().child('uploads/$fileName.$fileExtension');
                        await ref.putData(selectedImageBytes!);
                        newImageUrl = await ref.getDownloadURL();
                      }
                      await _postsRef.child(postKey).update({
                        'title': title,
                        'imageUrl': newImageUrl,
                        'githubLink': githubController.text.trim(),
                        'codeBlocks': codeList,
                      });
                      _fetchPosts();
                      if (mounted) _showSnackBar("Post updated successfully.");
                    } catch (e) {
                      if (mounted) _showSnackBar("Error updating post: $e", Colors.red);
                    }
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost(String key, String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      await _postsRef.child(key).remove();
      _fetchPosts();
      if (mounted) _showSnackBar("Post deleted successfully.");
    } catch (e) {
      if (mounted) _showSnackBar("Error deleting post: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Welcome, ${user?.email ?? 'User'}!",
              style: const TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : posts.isEmpty
                    ? const Center(child: Text("No posts available."))
                    : ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  post['imageUrl']!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.scaleDown, // shrink-only to fit
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    );
                                  },
                                ),
                              ),
                              title: Text(
                                post['title'] ?? 'Untitled Post',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailsPage(
                                      title: post['title'] ?? '',
                                      imageUrl: post['imageUrl']!,
                                      githubLink: post['githubLink'] ?? '',
                                      codeBlocks: List<String>.from(post['codeBlocks'] ?? []),
                                      postKey: post['key']!,
                                    ),
                                  ),
                                );
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: "Edit Post",
                                    onPressed: () {
                                      _editPost(
                                        post['key']!,
                                        post['title']!,
                                        post['imageUrl']!,
                                        post['githubLink']!,
                                        List<String>.from(post['codeBlocks']!),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: "Delete Post",
                                    onPressed: () {
                                      final confirmController = TextEditingController();
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text("Confirm Deletion"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                  "This action cannot be undone. Type 'DELETE' to confirm."),
                                              const SizedBox(height: 10),
                                              TextField(
                                                controller: confirmController,
                                                decoration: const InputDecoration(
                                                  labelText: 'Confirmation',
                                                  hintText: 'Type DELETE',
                                                  border: OutlineInputBorder(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () {
                                                if (confirmController.text.trim().toUpperCase() == 'DELETE') {
                                                  if (mounted) {
                                                    Navigator.pop(context);
                                                    _deletePost(post['key']!, post['imageUrl']!);
                                                  }
                                                } else {
                                                  if (mounted) {
                                                    _showSnackBar('You must type DELETE to confirm.', Colors.orange);
                                                  }
                                                }
                                              },
                                              child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewPost,
        child: const Icon(Icons.add),
        tooltip: "Add New Post",
      ),
    );
  }
}
