import 'dart:async';
import 'dart:ffi';

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
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  // double lat = 0;
  // double long = 0;
  // List<double> latlong = [];
  @override
  Widget build(BuildContext context) {

    // //completer
    // final completer = Completer<List>();
    // Future<List> future = completer.future;

    // Future nowLocation() async {
    //   print('start');
    //   Position position = await Geolocator.getCurrentPosition(
    //     desiredAccuracy: LocationAccuracy.high);
    //   lat = position.latitude;
    //   long = position.longitude;
    //   print('非同期$lat');
    //   List<double> latlong = [lat,long];
    //   completer.complete(latlong);
    //   print('latlong $latlong');
    //   print('completer $completer');
    // }

    // nowLocation();
    // future.then((value) => print(value));
    // //completer    
    
    // print('これはhomeでのnowLocation');
    // print(future.then);

    return Scaffold(
      body: const Center(
        child: 
        Text('Home'),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
          final lat = position.latitude;
          final long = position.longitude;
          print('非同期$lat');
          List<double> latlong = [lat,long];
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => MapPage(value: latlong)
            ),
          );
        },
      ),
    );
  }
}



class MapPage extends StatefulWidget {
  //const MapPage({super.key});
  final List value;

  const MapPage({Key? key, required this.value}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}
class _MapPageState extends State<MapPage> {
  String _title = 'Sample flutter_map mmmmmm';
  List<CircleMarker> circleMarkers = [];
  double la = 35.681;
  double lo =  139.767;
  late double lat;
  late double long;

  @override
  void initState() {
    super.initState();
    initLocation();
    // 受け取ったデータを状態を管理する変数に格納
    lat = widget.value[0];
    long = widget.value[1];
  }

  @override
  Widget build(BuildContext context) {
    nowLocation();
    print('----');
    print('la: $lat, lo: $long');
    print('----');

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
        body: Stack(
          children: [
            FlutterMap(
              // マップ表示設定
              options: MapOptions(
                initialCenter: LatLng(lat, long),
                //initialCenter: LatLng(43.0602767, 141.379295),
                initialZoom: 12.0,
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

            
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () {
            // Navigator.pushReplacement(
            //   context,
            //   MaterialPageRoute(
            //       builder: (BuildContext context) => super.widget)
            // );
          },
        ),
      ),
    );
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

  //現在位置を返す
  Future nowLocation() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
    la = position.latitude;
    lo = position.longitude;
  }

  void initCircleMarker(double latitude, double longitude) {
    print(latitude);
    print(longitude);
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


