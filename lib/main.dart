import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  final int intervalSeconds = 2;
  late GoogleMapController mapController;
  LatLng _currentPosition =
      LatLng(37.7749, -122.4194); // Default location (San Francisco)

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
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (timer) {
      _takePictureAndSend();
    });

    _getLocationUpdates();
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

      // Get current location
      Position position = await _getLocation();

      // Send the image and location data to the server
      await _sendImageToApi(image.path, position.latitude, position.longitude);
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Request location permissions if not already granted
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // Get current location
    return await Geolocator.getCurrentPosition();
  }

  void _getLocationUpdates() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    });
  }

  Future<void> _sendImageToApi(
      String imagePath, double latitude, double longitude) async {
    final uri = Uri.parse("http://98.11.205.187:45670/upload");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imagePath,
      contentType: MediaType('image', 'jpeg'),
    ));

    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        print("Image uploaded successfully with location data");
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
      appBar: AppBar(title: const Text('Camera App with Map')),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: _currentPosition,
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: MarkerId("currentLocation"),
            position: _currentPosition,
            infoWindow: InfoWindow(title: "You are here"),
          ),
        },
      ),
    );
  }
}
