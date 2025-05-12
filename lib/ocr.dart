import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;

class OCRScreen extends StatefulWidget {
  const OCRScreen({Key? key}) : super(key: key);

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _image;
  String lastName = '';
  String middleName = '';
  String givenNames = '';

  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _givenNamesController = TextEditingController();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      final originalImage = File(pickedFile.path);
      final processedImage = await _preprocessImage(originalImage);

      setState(() {
        _image = processedImage;
        lastName = '';
        middleName = '';
        givenNames = '';
        _lastNameController.clear();
        _middleNameController.clear();
        _givenNamesController.clear();
      });

      await _performOCR(processedImage);
    }
  }

  Future<File> _preprocessImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);

    if (original != null) {
      final grayscale = img.grayscale(original);
      final resized = img.copyResize(grayscale, width: 1000);

      final outputPath = '${imageFile.path}_processed.jpg';
      final processedFile = File(outputPath)
        ..writeAsBytesSync(img.encodeJpg(resized));
      return processedFile;
    }

    return imageFile;
  }

  Future<void> _performOCR(File imageFile) async {
    try {
      final text = await FlutterTesseractOcr.extractText(
        imageFile.path,
        language: 'eng+fil',
        args: {"preserve_interword_spaces": "1"},
      );

      _extractName(text);
    } catch (e) {
      setState(() {
        lastName = 'OCR error: $e';
        middleName = '';
        givenNames = '';
      });
    }
  }

  void _extractName(String text) {
    final lines =
        text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();

    String tempLast = '';
    String tempMiddle = '';
    String tempGiven = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();

      // Match Last Name
      if ((line.contains('apelyido') && !line.contains('gitnang')) ||
          line.contains('last name')) {
        if (i + 1 < lines.length) {
          tempLast = lines[i + 1];
        }
      }

      // Match Middle Name
      if (line.contains('gitnang') || line.contains('middle name')) {
        if (i + 1 < lines.length) {
          tempMiddle = lines[i + 1];
          // Check if middle name may span multiple lines
          if (i + 2 < lines.length && lines[i + 2].split(' ').length > 1) {
            tempMiddle += ' ' + lines[i + 2];
          }
        }
      }

      // Match Given Name(s)
      if (line.contains('pangalan') ||
          line.contains('given') ||
          line.contains('mga pangalan')) {
        if (i + 1 < lines.length) {
          tempGiven = lines[i + 1];
          // Check if given name may span multiple lines
          if (i + 2 < lines.length && lines[i + 2].split(' ').length > 1) {
            tempGiven += ' ' + lines[i + 2];
          }
        }
      }
    }

    // Adjusting to remove unwanted terms and keeping only capital letters
    tempMiddle = _filterMiddleName(tempMiddle);

    setState(() {
      lastName = tempLast.trim();
      middleName =
          tempMiddle.trim().toUpperCase(); // Make middle name uppercase
      givenNames = tempGiven.trim();

      _lastNameController.text = lastName;
      _middleNameController.text = middleName;
      _givenNamesController.text = givenNames;
    });
  }

  // Function to remove unwanted words or lines from the middle name
  String _filterMiddleName(String middleName) {
    final unwantedTerms = [
      'petsa ng kapanganakan',
      'date of birth',
      // Add any additional terms that need to be excluded here
    ];

    for (var term in unwantedTerms) {
      middleName = middleName.replaceAll(
        RegExp(term, caseSensitive: false),
        '',
      );
    }

    return middleName;
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _middleNameController.dispose();
    _givenNamesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extract Name from National ID')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Extracted Name:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _middleNameController,
                decoration: const InputDecoration(
                  labelText: 'Middle Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _givenNamesController,
                decoration: const InputDecoration(
                  labelText: 'Given Names',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _image != null
                  ? Image.file(_image!, height: 250)
                  : const Placeholder(fallbackHeight: 200),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Pick ID Image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
