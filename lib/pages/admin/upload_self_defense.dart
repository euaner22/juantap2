import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class UploadSelfDefenseImagesPage extends StatefulWidget {
  const UploadSelfDefenseImagesPage({super.key});
  @override
  State<UploadSelfDefenseImagesPage> createState() =>
      _UploadSelfDefenseImagesPageState();
}

class _UploadSelfDefenseImagesPageState
    extends State<UploadSelfDefenseImagesPage> {
  // 🔑 Fill with your actual Cloudinary credentials
  static const String kCloudName = 'dfop0muxq'; // your cloud name
  static const String kUnsignedPreset = 'juantap_images'; // your unsigned preset
  static const String kCloudFolder = 'self_defense_guides'; // folder

  final _title = TextEditingController();
  final _desc = TextEditingController();

  final List<Uint8List> _images = [];
  final List<String> _imageNames = [];
  bool _isUploading = false;

  static const int kMaxPickBytes = 8 * 1024 * 1024; // 8MB cap pre-compress
  static const int kTargetWidth = 1080; // resize target
  static const int kJpegQuality = 75; // 0..100

  /// Pick multiple images from gallery
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;

    int added = 0;
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > kMaxPickBytes) {
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.name} skipped (over 8 MB)')),
        );
        continue;
      }
      _images.add(bytes);
      _imageNames.add(f.name);
      added++;
    }
    if (added > 0 && mounted) setState(() {});
  }

  void _removeAt(int i) {
    _images.removeAt(i);
    _imageNames.removeAt(i);
    setState(() {});
  }

  /// Compress image before uploading
  Future<Uint8List> _compressToJpeg(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw 'Unsupported image';
    img.Image out = decoded;
    if (decoded.width > kTargetWidth) {
      out = img.copyResize(decoded, width: kTargetWidth);
    }
    final jpg = img.encodeJpg(out, quality: kJpegQuality);
    return Uint8List.fromList(jpg);
  }

  /// Upload a single image to Cloudinary and return secure URL
  Future<String> _uploadToCloudinary(Uint8List jpgBytes, String filename) async {
    final uri =
    Uri.parse('https://api.cloudinary.com/v1_1/$kCloudName/image/upload');

    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = kUnsignedPreset
      ..fields['folder'] = kCloudFolder
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        jpgBytes,
        filename: filename,
        contentType: MediaType('image', 'jpeg'),
      ));

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw 'Cloudinary upload failed (${res.statusCode}): ${res.body}';
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;
    if (secureUrl == null) throw 'No secure_url returned by Cloudinary';
    return secureUrl;
  }

  /// Compress + upload all picked images → save guide to Firebase
  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _desc.text.trim().isEmpty ||
        _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add title, description, and at least one image.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      // Upload each image to Cloudinary
      final List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        final jpg = await _compressToJpeg(_images[i]);
        final url = await _uploadToCloudinary(jpg, _imageNames[i]);
        imageUrls.add(url);
      }

      // Save guide metadata + Cloudinary URLs to Firebase
      await FirebaseDatabase.instance.ref('self_defense_guides').push().set({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'images': imageUrls, // list of Cloudinary URLs
        'uploaded_at': DateTime.now().toIso8601String(),
        'source': 'cloudinary',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guide saved ✅')),
      );

      _images.clear();
      _imageNames.clear();
      _title.clear();
      _desc.clear();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Self-Defense Guide'),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.collections),
              label: const Text('Pick Images'),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_images.length, (i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _images[i],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _removeAt(i),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A9D8F),
              ),
              child: _isUploading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save Guide'),
            ),
          ],
        ),
      ),
    );
  }
}
