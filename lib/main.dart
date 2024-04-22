import 'dart:async';
//import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

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

    return Scaffold(
      body: const Center(
        child: 
        Text('Home'),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          Location location = new Location();
          bool _serviceEnabled;
          PermissionStatus _permissionGranted;
          LocationData _locationData;
          _serviceEnabled = await location.serviceEnabled();
          if (!_serviceEnabled) {
            _serviceEnabled = await location.requestService();
            if (!_serviceEnabled) {
              return;
            }
          }
          print("!");
          _permissionGranted = await location.hasPermission();
          if (_permissionGranted == PermissionStatus.denied) {
            _permissionGranted = await location.requestPermission();
            if (_permissionGranted != PermissionStatus.granted) {
              return;
            }
          }
          _locationData = await location.getLocation();
          print("!!");

          //Position position = await Geolocator.getCurrentPosition(
          //  desiredAccuracy: LocationAccuracy.high);
          final lat = _locationData.latitude!;
          final long = _locationData.longitude!;
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

  //マーカー用のList
  List<Marker> addMarkers = [];
  //ピンを追加する関数
  void _addMarker(LatLng latlong) {
    //マップの更新
    setState(() {
      addMarkers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: latlong, 
          child: GestureDetector(
            onTap:(){
              _tapMarker(latlong);
            },
            child: const Icon(
              Icons.location_on,
              color: Colors.green,
              size: 50,
            ),
          ),
          rotate: true,
        ),
      );
    });
  }
  //マーカー押した時の処理
  void _tapMarker(LatLng latlong) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('ピンの位置'),
        content: Text('緯度：${latlong.latitude} \n 経度：${latlong.longitude}'),
        actions: <Widget>[
          TextButton(
            child: const Text('閉じる'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      )
    );
  }

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
        body: Stack(
          children: [
            FlutterMap(
              // マップ表示設定
              options: MapOptions(
                initialCenter: LatLng(lat, long),
                //initialCenter: LatLng(43.0602767, 141.379295),
                initialZoom: 12.0,
                //pointはタップした位置がLatLong型で受け取る
                onTap: (tapPosition, point) {
                  _addMarker(point);
                },
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
                //MarkerLeyerに追加したピンの指定
                MarkerLayer(markers: addMarkers),
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
    bool _serviceEnabled;
    Location location = new Location();
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return Future.error('Location permissions are denied');      
      }
    }
    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return Future.error('Location permissions are denied');      
      }
    }

    
    LocationData _locationData = await location.getLocation();
    final latitude = _locationData.latitude!;
    final longitude = _locationData.longitude!;
    initCircleMarker(latitude, longitude);
    setState(() {});
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


