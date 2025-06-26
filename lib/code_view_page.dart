import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart'; // For Clipboard

class CodeViewPage extends StatefulWidget {
  final List<String> codes;
  final String postKey;

  const CodeViewPage({
    super.key,
    required this.codes,
    required this.postKey,
  });

  @override
  State<CodeViewPage> createState() => _CodeViewPageState();
}

class _CodeViewPageState extends State<CodeViewPage> {
  late List<String> _codeList;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _codeList = List.from(widget.codes);
  }

  Future<void> _saveCodesToFirebase() async {
    try {
      await _db.child("posts/${widget.postKey}/codeBlocks").set(_codeList);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Na-save ang mga pagbabago sa Firebase.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Nabigo ang pag-save ng mga pagbabago: $e")),
      );
    }
  }

  void _addNewCode() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Magdagdag ng Bagong Code"),
        content: TextField(
          controller: codeController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: "Ilagay ang iyong code dito...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kanselahin"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newCode = codeController.text.trim();
              if (newCode.isNotEmpty) {
                setState(() {
                  _codeList.add(newCode);
                });
                await _saveCodesToFirebase();
                Navigator.pop(context);
              }
            },
            child: const Text("Idagdag"),
          ),
        ],
      ),
    );
  }

  void _editCode(int index, String currentCode) {
    final TextEditingController codeController = TextEditingController(text: currentCode);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("I-edit ang Code"),
        content: TextField(
          controller: codeController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: "I-edit ang iyong code dito...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kanselahin"),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedCode = codeController.text.trim();
              if (updatedCode.isNotEmpty) {
                setState(() {
                  _codeList[index] = updatedCode;
                });
                await _saveCodesToFirebase();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Hindi maaaring walang laman ang code.")),
                );
              }
            },
            child: const Text("I-save"),
          ),
        ],
      ),
    );
  }

  void _deleteCode(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Tanggalin ang Code"),
        content: const Text("Sigurado ka bang gusto mong tanggalin ang code block na ito?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Kanselahin"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              setState(() {
                _codeList.removeAt(index);
              });
              await _saveCodesToFirebase();
              Navigator.pop(context);
            },
            child: const Text("Tanggalin"),
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Code naka-copy na sa clipboard!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Code Viewer"),
        backgroundColor: Colors.blueGrey,
      ),
      body: _codeList.isEmpty
          ? const Center(
              child: Text(
                'Walang available na code blocks. I-click ang "Magdagdag ng Code" para magsimula!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 32,
                vertical: isMobile ? 12 : 24,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isMobile ? 2.5 : 1.0,
              ),
              itemCount: _codeList.length,
              itemBuilder: (context, index) {
                final code = _codeList[index];
                return _buildCodeBlock(code, index, isMobile);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewCode,
        icon: const Icon(Icons.add),
        label: const Text("Magdagdag ng Code"),
        tooltip: "Magdagdag ng bagong code block",
      ),
    );
  }

  Widget _buildCodeBlock(String code, int index, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.greenAccent,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white70),
                  onPressed: () => _copyCode(code),
                  tooltip: "Copy code to clipboard",
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () => _editCode(index, code),
                  tooltip: "I-edit ang code block",
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteCode(index),
                  tooltip: "Tanggalin ang code block",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
