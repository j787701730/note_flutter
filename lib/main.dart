import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart' hide MenuItem;
import 'package:protocol_handler/protocol_handler.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  await protocolHandler.register('noteflutter');
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    minimumSize: Size(800, 600),
    center: true,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setTitle("笔记");
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TrayListener, WindowListener {
  bool maximizeFlag = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    setTray();
  }

  setTray() async {
    // 开启关闭拦截功能
    await windowManager.setPreventClose(true);
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );
    List<MenuItem> items = [
      MenuItem(
        key: 'show_window',
        label: '显示',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit_app',
        label: '退出',
      ),
    ];
    await trayManager.setContextMenu(Menu(items: items));
    await trayManager.setToolTip("笔记");
  }

  @override
  void onWindowMaximize() {
    maximizeFlag = true;
  }

  @override
  void onWindowUnmaximize() {
    maximizeFlag = false;
  }

  @override
  void onWindowClose() {
    windowManager.hide();
  }

  windowShow() async {
    if (await windowManager.isMinimized()) {
      if (maximizeFlag) {
        windowManager.maximize();
      } else {
        windowManager.restore();
      }
    } else {
      windowManager.show().then((value) {
        setState(() {});
        if (maximizeFlag) windowManager.maximize();
      });
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowShow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowShow();
    } else if (menuItem.key == 'exit_app') {
      // 退出
      trayManager.destroy().then((_) => exit(0));
    }
  }

  @override
  void dispose() {
    super.dispose();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '笔记',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        fontFamily: "微软雅黑",
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            elevation: MaterialStateProperty.all(0),
          ),
        ),
      ),
      home: const HomePage(),
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
    );
  }
}
