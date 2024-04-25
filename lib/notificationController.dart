import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationController{
  // 「flutter_local_notifications」にあるローカル通知を扱うためのクラスをインスタンス化 
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await notificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();//requestPermission();
    }
  }

  // 通知を表示する
  Future<void> showNotification() async{

    // 初期設定
    Future<void> initNotification() async{
      // プラットフォームごとの初期設定をまとめる(今回はAndroidのみ)
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('icon')
      );
      // 通知設定を初期化(先程の設定＋通知をタップしたときの処理)
      await notificationsPlugin.initialize(
        initializationSettings,
        // 通知をタップしたときの処理(今回はprint)
        onDidReceiveNotificationResponse: 
          (NotificationResponse notificationResponse) async{
            print('id=${notificationResponse.id}の通知に対してアクション。');
          },
      );
    }

    print("showNotification");
    // プラットフォームごとの詳細設定
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'channelId', 
        'channelName',
        icon: "icon",
      )
    );
    // 通知を表示
    await notificationsPlugin.show(
      0,
      "title",
      "body",
      notificationDetails,
    );
  }
}