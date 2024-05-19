import 'dart:async';
//import 'dart:ffi';

import 'package:alarm/model/alarm_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:place_reminder/model/reminder.dart';
import 'package:vibration/vibration.dart';
import 'notificationController.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//import 'package:flutter_native_timezone/flutter_native_timezone.dart'; //これもう古いらしい
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
//import 'package:isar_app/model/reminder.dart';
//import 'package:isar_app/view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:alarm/alarm.dart';
import 'dart:math';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ReminderSchema],
    directory: dir.path,
  );
  runApp(MyApp(isar: isar));
}

class MyApp extends StatelessWidget {
  final Isar isar;

  MyApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Home(isar: isar),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key, required this.isar}) : super(key: key);
  final Isar isar;

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
    loadData();
    initLocation();
    getLocation();
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

  List<Reminder> reminders = [];
  // データベースの中身を取得する関数
  Future<void> loadData() async {
    final data = await widget.isar.reminders.where().findAll();
    setState(() {
      reminders = data;
    });
  }

  // 位置情報　常に現在位置を取得して関数が動くようにする
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
  }
  bool onAlarm = false;
  final double  RX = 6378.137; // 回転楕円体の長半径（赤道半径）[km]
  final double RY = 6356.752; // 回転楕円体の短半径（極半径) [km]
  LocationData? _currentLocation;
  List<CircleMarker> circleMarkers = [];
  Location location = Location();
  double dis = 0;
  double change_lat = 35.6809591; // 東京駅
  double change_long = 139.7673068; // 東京駅
  //緯度軽度から距離を計算
  double hubeny_distance(double x1, double y1, double x2, double y2) {
    double dx = x2 - x1, dy = y2 - y1;
    double mu = (y1 + y2) / 2.0; // μ
    double E = sqrt(1 - pow(RY / RX, 2.0)); // 離心率
    double W = sqrt(1 - pow(E * sin(mu), 2.0));
    double M = RX * (1 - pow(E, 2.0)) / pow(W, 3.0); // 子午線曲率半径
    double N = RX / W; // 卯酉線曲率半径
    return sqrt(pow(M * dy, 2.0) + pow(N * dx * cos(mu), 2.0)); // 距離[km]
  }
  Future<void> getLocation() async {
    location.onLocationChanged.listen((LocationData currentLocation) {
      change_lat = currentLocation.latitude!; 
      change_long = currentLocation.longitude!; 
      setState(() {
        _currentLocation = currentLocation;
        for (Reminder item in reminders) {
          dis = hubeny_distance(change_lat, change_long, item.lat!, item.long!);
          print("キョリ　[$dis] m");
          if (dis < 0.5 && !onAlarm) {
            startAlarm();
            onAlarm = true;
          }
        };
        print("更新された位置情報");
        print(_currentLocation);
      });
    });
    await location.changeSettings(
      accuracy: LocationAccuracy.high, //LocationAccuracy.powerSave にすると低電力で最大の精度
      distanceFilter: 2, // mの位置変化で観測
    );
  }
  Future<void> startAlarm() async {
    print("start");
    await Alarm.init();
    DateTime now = DateTime.now();
    now = now.add(Duration(seconds: 10));
    AlarmSettings alarmSettings = AlarmSettings(
      id: 42,
      dateTime: now,
      assetAudioPath: 'assets/walk.mp3',
      loopAudio: true,
      vibrate: true,
      fadeDuration: 3.0,
      notificationTitle: 'This is the title',
      notificationBody: 'This is the body',
      enableNotificationOnKill: true,
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        child: ListView.builder(
          itemCount: reminders.length,
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return ListTile(
              title: Text(
                reminder.title ?? "!! 値が入ってません !!",
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 10,
                children: [
                  IconButton(
                    icon: Icon(Icons.pause),
                    onPressed: () async {
                      print("stop!!");
                      await Alarm.stop(42);
                      if (onAlarm) {
                        onAlarm = false;
                      }
                    }, 
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      // ここでデータベースから削除しています
                      await widget.isar.writeTxn(() async {
                        await widget.isar.reminders.delete(reminder.id);
                      });
                      await loadData();
                    },
                  ),
                ],
              )
            );
          },
        ),
      ),
      
      // Center(
      //   child: Column(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: <Widget>[
      //       Text('Home'),

            //データ表示
            // ListView.builder(
            //     itemCount: reminders.length,
            //     itemBuilder: (context, index) {
                  // final reminder = reminders[index];
            //       return ListTile(
            //         title: Text(reminder.title ?? "値が入ってません"),
            //         trailing: IconButton(
            //           icon: const Icon(Icons.delete),
            //           onPressed: () async {
            //             // ここでデータベースから削除しています
            //             await widget.isar.writeTxn(() async {
            //               await widget.isar.reminders.delete(reminder.id);
            //             });
            //             await loadData();
            //           },
            //         )
            //       );
            //     }
            // ),
            /*
            ElevatedButton(
              onPressed: () async {
                // 振動させる
                Vibration.vibrate();
                // １秒間振動させる
                Vibration.vibrate(duration: 1000);
                // 振動を止める
                Vibration.cancel();
                //data挿入
                final title = "test1";
                final memo = "body1";
                final isVib = true;
                final laat = 13.5;
                final loonng = 177.5;
                final reminder = Reminder() 
                  ..title = title
                  ..memo = memo
                  ..isVib = isVib
                  ..lat = laat
                  ..long = loonng;
                  await widget.isar.writeTxn(() async{
                    await widget.isar.reminders.put(reminder);
                    await loadData();
                    print(reminders[0].title);
                    print(reminders.length);
                  });
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
            */
      //     ],
      //   ),
      // ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.map_outlined),
        onPressed: () async {
          print("!");
          print('非同期$change_lat,$change_long');
          List<double> latlong = [change_lat,change_long];
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => MapPage(value: latlong, isar: widget.isar, reminders: reminders),
            ),
          );
        },
      ),



      // floatingActionButton: Row(
      //   children: [
      //     Container(
      //       child: FloatingActionButton(
      //         child: Icon(Icons.map_outlined),
      //         onPressed: () async {
      //           print("!");
      //           print('非同期$change_lat,$change_long');
      //           List<double> latlong = [change_lat,change_long];
      //           Navigator.push(
      //             context, 
      //             MaterialPageRoute(
      //               builder: (context) => MapPage(value: latlong, isar: widget.isar, reminders: reminders),
      //             ),
      //           );
      //         },
      //       ),
      //     ),
      //     FloatingActionButton(
      //       child: Icon(Icons.check),
      //       onPressed: () async {
      //         print("２個目のボタン");
      //         await Alarm.init();
      //         DateTime now = DateTime.now();
      //         now = now.add(Duration(seconds: 10));
      //         AlarmSettings alarmSettings = AlarmSettings(
      //           id: 42,
      //           dateTime: now,
      //           assetAudioPath: 'assets/walk.mp3',
      //           loopAudio: true,
      //           vibrate: true,
      //           fadeDuration: 3.0,
      //           notificationTitle: 'This is the title',
      //           notificationBody: 'This is the body',
      //           enableNotificationOnKill: true,
      //         );
      //         await Alarm.set(alarmSettings: alarmSettings);
      //       },
      //     ),
      //     FloatingActionButton(
      //       child: Icon(Icons.stop),
      //       onPressed: () async {
      //         print("２個目のボタン");
      //         await Alarm.stop(42);
      //       },
      //     )
      //   ],
      // ),
    );
  }
}








class MapPage extends StatefulWidget {
  const MapPage({Key? key, required this.value, required this.isar, required this.reminders}) : super(key: key);
  final Isar isar;
  final List value;
  final List<Reminder> reminders;

  @override
  State<MapPage> createState() => _MapPageState();
}
class _MapPageState extends State<MapPage> {
  List<CircleMarker> circleMarkers = [];
  double celect_la = 35.681; //選択した場所の緯度経度。リマインド作成用
  double celect_lo =  139.767;
  late double lat;
  late double long;
  bool addMode = false;
  var mapIcon = Icon(Icons.add);
  bool isCelectPlace = false; //場所を選択しているか。trueでリマインド作成可能
  Location location = Location();
  LocationData? _currentLocation;
  List<Reminder> reminders = [];

  @override
  void initState() {
    super.initState();
    initLocation();
    // 受け取ったデータを状態を管理する変数に格納
    lat = widget.value[0];
    long = widget.value[1];
    reminders = widget.reminders;
    //loadData();
    loadMapPin();
    getLocation();
  }

  final double  RX = 6378.137; // 回転楕円体の長半径（赤道半径）[km]
  final double RY = 6356.752; // 回転楕円体の短半径（極半径) [km]
  //緯度軽度から距離を計算
  double hubeny_distance(double x1, double y1, double x2, double y2) {
    double dx = x2 - x1, dy = y2 - y1;
    double mu = (y1 + y2) / 2.0; // μ
    double E = sqrt(1 - pow(RY / RX, 2.0)); // 離心率
    double W = sqrt(1 - pow(E * sin(mu), 2.0));
    double M = RX * (1 - pow(E, 2.0)) / pow(W, 3.0); // 子午線曲率半径
    double N = RX / W; // 卯酉線曲率半径
    return sqrt(pow(M * dy, 2.0) + pow(N * dx * cos(mu), 2.0)); // 距離[km]
  }

  //位置情報が更新された時に動く
  double dis = 0;
  Future<void> getLocation() async {
    location.onLocationChanged.listen((LocationData currentLocation) {
      double change_lat = currentLocation.latitude!; 
      double change_long = currentLocation.longitude!; 
      chengeCircleMarker(change_lat, change_long);
      setState(() {
        _currentLocation = currentLocation;
        for (Reminder item in reminders) {
          dis = hubeny_distance(change_lat, change_long, item.lat!, item.long!);
          print("キョリ　[$dis] m");
        };
        print("更新された位置情報");
        print(_currentLocation);
      });
    });
    await location.changeSettings(
      accuracy: LocationAccuracy.high, //LocationAccuracy.powerSave にすると低電力で最大の精度
      distanceFilter: 2, // 3mの位置変化で観測
    );
  }

  List<Marker> addMarkers = [];
  List<Marker> addSelectMarker = [];
  //マーカー用のList
  //ピンを追加する関数
  void _addMarker(LatLng latlong,String title, String? memo, bool isVib) {
    addSelectMarker = []; // 候補ピンの初期化
    //マップの更新
    setState(() {
      addMarkers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: latlong, 
          child: GestureDetector(
            onTap:(){
              _tapMarker(title, memo, isVib);
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
  //remindd作成候補のピンを立てる
  void _addTempMarker(LatLng latlong) {
    if (isCelectPlace) {
      addSelectMarker.removeLast();
    }
    //マップの更新
    setState(() {
      addSelectMarker.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: latlong, 
          child: GestureDetector(
            child: const Icon(
              Icons.location_on,
              color: Color.fromARGB(255, 80, 193, 191),
              size: 50,
            ),
          ),
          rotate: true,
        ),
      );
    });
  }
  // データベースの中身を取得する関数
  Future<void> loadData() async {
    final data = await widget.isar.reminders.where().findAll();
    setState(() {
      reminders = data;
    });
  }
  void loadMapPin() {
    reminders.forEach((element) {
      LatLng lalo = LatLng(element.lat!, element.long!);
      addMarkers.add(
        Marker(
          width: 30.0,
          height: 30.0,
          point: lalo, 
          child: GestureDetector(
            onTap:(){
              _tapMarker(element.title!, element.memo, element.isVib!);
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
  void _tapMarker(String title, String? memo, bool isVib) {
    if (memo == null) {
      String memo = "メモなし";
    }
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis
        ),
        insetPadding: EdgeInsets.all(45), // 枠とのパディング
        content: Container(
                width: 400,
                height: 150,
          child: Column(
            children: [
              Container(
                width: 400,
                height: 120,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        memo!,
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              child: (isVib)?Text("バイブレーションあり"):Text("バイブレーションなし"),
            ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('閉じる'),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      )
    );
  }

  //マップ触った時の処理。リマインド作成候補
  void _celectPoint(LatLng latlong){
    setState(() {
      if (!isCelectPlace) {
        isCelectPlace = true;
      }
      celect_la = latlong.latitude;
      celect_lo = latlong.longitude;
    });
  }
  //ボタン押した時の処理.リマンダー作成ダイアログ出現
  void _modeChange(double lat, double long) {
    String title = "";
    String memo = "";
    bool _flagVib = false; // ダイアログのバイブレーション
    showDialog(
      barrierDismissible: false, // ダイアログの外をタップしても閉じない
      context: context, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: EdgeInsets.all(16), // 枠とのパディング
              
              content: Container(
                width: 400,
                height: 380,
                child: GestureDetector( // キーボード以外をタップすると閉じるためにGestureDetectorを使用
                  onTap: () {
                    print("画面外たっぷ");
                    FocusScope.of(context).unfocus();
                  },
                  child: ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextFormField(
                          decoration: const InputDecoration(icon: Icon(Icons.label_outline_sharp)),
                          onChanged: (value) {
                            title = value;
                          }
                        ),
                      ),
                      TextField(
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          minLines: 4,
                          decoration: InputDecoration(
                            labelText: "メモ",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(5.0), // 枠線の丸み
                            ),
                          ),
                          onChanged: (value){
                            memo = value;
                          },
                      ),
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          children: <Widget>[
                            CheckboxListTile(
                              activeColor: Colors.blue,
                              title: const Text('バイブレーションで通知を行う'),
                              //subtitle: Text('チェックボックスのサブタイトル'),
                              secondary: Icon(
                                Icons.waving_hand,
                                color: _flagVib ? Colors.orange[700] : Colors.grey[500],
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _flagVib,
                              onChanged:(bool? value) { 
                                setState(() {
                                  _flagVib = !_flagVib;
                                });
                              },
                            )
                          ]
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              //候補地ピンを削除
                              reminders.removeLast();
                              //reminderを作成しDBに挿入
                              final reminder = Reminder() 
                                ..title = title
                                ..memo = memo
                                ..isVib = _flagVib
                                ..lat = celect_la
                                ..long = celect_lo;
                                await widget.isar.writeTxn(() async{
                                  await widget.isar.reminders.put(reminder);
                                  await loadData();
                                  print(reminders[reminders.length-1].title);
                                  print(reminders.length);
                                });
                                _addMarker(LatLng(celect_la, celect_lo),title,memo,_flagVib); 

                              Navigator.of(context).pop(); // ダイアログを閉じる
                            }, 
                            child: const Text("追加"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            }, 
                            child: const Text("閉じる"),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),

              ),
              // actions: <Widget>[
              //   TextButton(
              //     child: const Text('閉じる'),
              //     onPressed: () => Navigator.of(context).pop(),
              //   )
              // ],
            );
            
          }
        );
      } 
    );
  }

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      //title: 'map_app',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        // flutter_map設定
        body: Stack(
          children: <Widget>[
            FlutterMap(
              // マップ表示設定
              options: MapOptions(
                initialCenter: LatLng(lat, long),
                //initialCenter: LatLng(43.0602767, 141.379295),
                initialZoom: 13.0,
                //pointはタップした位置がLatLong型で受け取る
                onTap: (tapPosition, point) {
                  _addTempMarker(point);
                  _celectPoint(point);
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
                MarkerLayer(markers: addMarkers+addSelectMarker),
              ],
            ),
            Stack(
              children: [
                Image.asset('images/marker.png'),
                Opacity(
                  opacity: 0.8,
                  )
              ],
            ),
            const Align(
              alignment: Alignment(-0.7, -0.8),
              child: Text(
                "場所を選択して\nリマインドを追加",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            //画面下部isSelect
            Align(
              alignment: Alignment(-0.08, 0.87),
              child: (isCelectPlace) ? Container(
                width: 300,
                height: 60,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 216, 216, 216),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Align(
                  alignment: Alignment(-0.4, 0),
                  child: Text(
                    '緯度:${celect_la.toStringAsFixed(3)}, 緯度:${celect_lo.toStringAsFixed(3)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ) : Container(),
            ),
            Align(
              alignment: Alignment(0.87,0.87),
              child: (isCelectPlace) ? ElevatedButton(
                  child: Icon(
                    Icons.edit_square,
                    size: 36,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    fixedSize: Size(80, 60)
                  ),
                  onPressed: () {
                    _modeChange(celect_la,celect_lo);
                  },
                ) : Container(),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.menu),
            onPressed: () async {
              Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => Home(isar: widget.isar),
              ),
            );
          }
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
  void chengeCircleMarker(double latitude, double longitude) {
    print(latitude);
    print(longitude);
    CircleMarker circleMarler = CircleMarker(
      color: Colors.indigo.withOpacity(0.9),
      radius: 10,
      borderColor: Colors.white.withOpacity(0.9),
      borderStrokeWidth: 3,
      point: LatLng(latitude, longitude),
    );
    circleMarkers.removeLast();
    circleMarkers.add(circleMarler);
  }
}





//閉じるボタン。使い回す
Widget closeButton(
  BuildContext context,
  double buttonSize,
  Function() onPressed,
) {
  return SizedBox(
    width: buttonSize * 1.2,
    height: buttonSize * 1.2,
    child: FloatingActionButton(
      child: Icon(
        Icons.clear,
        size: buttonSize,
        color: Colors.white,
      ),
      onPressed: () {
        onPressed();
      },
    ),
  );
}