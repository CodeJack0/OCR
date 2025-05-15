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
  String dateOfBirth = '';

  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _givenNamesController = TextEditingController();
  final _dobController = TextEditingController();

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
        dateOfBirth = '';
        _lastNameController.clear();
        _middleNameController.clear();
        _givenNamesController.clear();
        _dobController.clear();
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
        dateOfBirth = '';
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
    String tempDOB = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();

      if ((line.contains('apelyido') && !line.contains('gitnang')) ||
          line.contains('last name')) {
        if (i + 1 < lines.length) {
          tempLast = lines[i + 1];
        }
      }

      if (line.contains('gitnang') || line.contains('middle name')) {
        if (i + 1 < lines.length) {
          tempMiddle = lines[i + 1];
          if (i + 2 < lines.length && lines[i + 2].split(' ').length > 1) {
            tempMiddle += ' ' + lines[i + 2];
          }
        }
      }

      if (line.contains('pangalan') ||
          line.contains('given') ||
          line.contains('mga pangalan')) {
        if (i + 1 < lines.length) {
          tempGiven = lines[i + 1];
          if (i + 2 < lines.length && lines[i + 2].split(' ').length > 1) {
            tempGiven += ' ' + lines[i + 2];
          }
        }
      }

      if (line.contains('petsa ng kapanganakan') ||
          line.contains('date of birth')) {
        if (i + 1 < lines.length) {
          tempDOB = lines[i + 1];
        }
      }
    }

    // Fallback: find potential date pattern
    if (tempDOB.isEmpty) {
      for (var line in lines) {
        final match = RegExp(
          r'(\d{1,2}[\s\-\/]?[A-Za-z%]{3,9}[\s\-\/]?\d{2,4})',
          caseSensitive: false,
        ).firstMatch(line);
        if (match != null) {
          tempDOB = match.group(0)!;
          break;
        }
      }
    }

    tempMiddle = _filterMiddleName(tempMiddle);
    tempDOB = _correctOCRNoise(tempDOB);

    setState(() {
      lastName = tempLast.trim();
      middleName = tempMiddle.trim().toUpperCase();
      givenNames = tempGiven.trim();
      dateOfBirth = tempDOB.trim();

      _lastNameController.text = lastName;
      _middleNameController.text = middleName;
      _givenNamesController.text = givenNames;
      _dobController.text = dateOfBirth;
    });
  }

  String _filterMiddleName(String middleName) {
    final unwantedTerms = ['petsa ng kapanganakan', 'date of birth'];

    for (var term in unwantedTerms) {
      middleName = middleName.replaceAll(
        RegExp(term, caseSensitive: false),
        '',
      );
    }

    return middleName;
  }

  // Fix common OCR typos in month names
  String _correctOCRNoise(String input) {
    final corrections = {
      'vJ%UARY': 'January',
      'JANUARY': 'January',
      'FEBRUARY': 'February',
      'MARCH': 'March',
      'APRIL': 'April',
      'MAY': 'May',
      'JUNE': 'June',
      'JULY': 'July',
      'AUGUST': 'August',
      'SEPTEMBER': 'September',
      'OCTOBER': 'October',
      'NOVEMBER': 'November',
      'DECEMBER': 'December',
    };

    corrections.forEach((wrong, right) {
      input = input.replaceAll(RegExp(wrong, caseSensitive: false), right);
    });

    return input;
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _middleNameController.dispose();
    _givenNamesController.dispose();
    _dobController.dispose();
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
              const SizedBox(height: 10),
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
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
