import 'dart:async';
//import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:vibration/vibration.dart';
import 'notificationController.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:flutter_native_timezone/flutter_native_timezone.dart'; //これもう古いらしい
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
class _HomeState extends State<Home> with WidgetsBindingObserver { //WidgetsBindingObserver で状態を監視 paused.resumed.inactive.detached
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  //flutter_local_notificationの初期化
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this); //状態管理
    _init();
  }
  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this); //状態管理
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      //FlutterAppBadger.removeBadge();
    }
  }
  Future<void> _init() async {
    await _configureLocalTimeZone();
    await _initializeNotification();
  }
  // 端末の現在時間を登録
  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName!));
  }
  // iOSのメッセージ権限リクエストを初期化
  Future<void> _initializeNotification() async {
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
  Future<void> _cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancelAll(); //cancelAll()を使い以前登録されたメッセをキャンセル
  }
  //iOSに権限をリクエスト
  Future<void> _requestPermissions() async {
    await _flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
  }
  //メッセージ登録の関数
  Future<void> _registerMessage({
    required int hour,
    required int minutes,
    required message,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minutes,
    );
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'flutter_local_notifications',
      message,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel id',
          'channel name',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          styleInformation: BigTextStyleInformation(message),
          icon: 'icon',
        ),
        iOS: const DarwinNotificationDetails(
          badgeNumber: 1,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    print('push通知');
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Home'),
            ElevatedButton(
              onPressed: () async {
                // 振動させる
                Vibration.vibrate();
                // // 振動機能があるか確認する
                // if (await Vibration.hasVibrator()) {
                //     Vibration.vibrate();
                // }
                // １秒間振動させる
                Vibration.vibrate(duration: 1000);
                // 振動を止める
                Vibration.cancel();
              }, 
              child: Text('実験用ボタン'),
            ),
            ElevatedButton(
              onPressed: ()async{
                await _cancelNotification(); //登録されていたメッセージ削除
                await _requestPermissions(); //権限
                //await NotificationController().showNotification(); //別dartファイルの関数呼び出し
                final tz.TZDateTime now = tz.TZDateTime.now(tz.local); //現在時刻取得
                await _registerMessage(
                  hour: now.hour, 
                  minutes: now.minute + 1, 
                  message: 'Hello World!',
                );
              }, 
              child: const Text('push通知')
            ),
          ],
        ),
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


