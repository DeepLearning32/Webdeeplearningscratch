import 'package:flutter/material.dart'; // Core Flutter widgets
import 'package:url_launcher/url_launcher.dart'; // For launching URLs (e.g., GitHub links)
import 'code_view_page.dart'; // Import for navigating to the code view page

class PostDetailsPage extends StatelessWidget {
  final String postKey;
  final String title;
  final String imageUrl;
  final String githubLink;
  final List<String> codeBlocks;

  const PostDetailsPage({ // Changed to const constructor
    super.key,
    required this.postKey,
    required this.title,
    required this.imageUrl,
    required this.githubLink,
    required this.codeBlocks,
  });

  /// Attempts to launch the provided GitHub link.
  /// Shows a SnackBar if the link cannot be launched.
  Future<void> _launchGitHubLink(BuildContext context) async {
    final Uri url = Uri.parse(githubLink);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Could not open the GitHub link.', Colors.red);
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, 'Error launching GitHub link: $e', Colors.red);
      }
    }
  }

  /// Displays a SnackBar with the given message and color.
  void _showSnackBar(BuildContext context, String message, [Color color = Colors.green]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600; // Define breakpoint for wide screens

    // Common content for both wide and narrow screen layouts
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Placeholder for a detailed description
        const Text(
          "Here you can add a detailed description of your project or post. "
          "Explain its purpose, key features, technologies used, and any "
          "other relevant information that would be helpful to the user. "
          "You can also include more images or embedded videos here if needed.",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.justify, // Justify text for better readability
        ),
        const SizedBox(height: 20),
        // GitHub Link Button (only if link is not empty)
        if (githubLink.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => _launchGitHubLink(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text("Open GitHub Repository"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        const SizedBox(height: 10),
        // View Code Button (only if code blocks exist)
        if (codeBlocks.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CodeViewPage(
                    codes: codeBlocks,
                    postKey: postKey,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.code),
            label: Text("View Code (${codeBlocks.length} blocks)"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Post Details"),
        centerTitle: false, // Align title to start
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isWideScreen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image container for wide screens
                  Container(
                    width: screenWidth * 0.4, // Occupy 40% of screen width
                    height: 350, // Slightly increased height for better viewing
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16), // More rounded corners
                      color: Colors.grey[200],
                      boxShadow: [ // Added a subtle shadow
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias, // Use antiAlias for smoother clipping
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain, // <-- changed from cover to contain
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.grey)),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  const SizedBox(width: 32), // Increased spacing for wide screens
                  Expanded(child: content), // Content takes remaining space
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image container for narrow screens
                  Container(
                    width: double.infinity, // Occupy full width
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16), // More rounded corners
                      color: Colors.grey[200],
                      boxShadow: [ // Added a subtle shadow
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 2,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain, // <-- changed from cover to contain
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.grey)),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  content, // Content below the image for narrow screens
                ],
              ),
      ),
    );
  }
}
