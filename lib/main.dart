import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: const MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  String _title = 'Sample flutter_map mmmmmm';
  List<CircleMarker> circleMarkers = [];

  @override
  Widget build(BuildContext context) {
      return MaterialApp(
      title: 'map_app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(_title),
        ),
        // flutter_map設定
        body: FlutterMap(
          // マップ表示設定
          options: const MapOptions(
            initialCenter: LatLng(35.681, 139.767),
            initialZoom: 14.0,
          ),
          children: [
            // 背景地図読み込み (OSM)
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.jp/{z}/{x}/{y}.png",
            ),// OpenStreetMap-APIを使用
            // サークルマーカー設定
            CircleLayer(
              circles: circleMarkers,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    initLocation();
  }

  Future<void> initLocation() async {
    LocationPermission permission; permission = await Geolocator.requestPermission();
    //LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final latitude = position.latitude;
    final longitude = position.longitude;
    initCircleMarker(latitude, longitude);
    setState(() {});
  }

  void initCircleMarker(double latitude, double longitude) {
    CircleMarker circleMarler = CircleMarker(
      color: Colors.indigo.withOpacity(0.9),
      radius: 10,
      borderColor: Colors.white.withOpacity(0.9),
      borderStrokeWidth: 3,
      point: LatLng(latitude, longitude),
    );
    circleMarkers.add(circleMarler);
  }
}