import 'dart:convert';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intranet_ip/intranet_ip.dart';
import 'package:path/path.dart' as p;
import 'package:process_run/shell.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:shelf_plus/shelf_plus.dart' as plus;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  plus.RouterPlus app = plus.Router().plus;
  String webPath = '';
  String noteDataPath = '';
  String ip = '';
  Uuid uuid = const Uuid();

  @override
  initState() {
    super.initState();
    webPath = p.join(p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/web/');
    noteDataPath = p.join(p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/note_data/');
    if (kDebugMode) {
      // 当前目录下的web文件夹
      webPath = '${p.current}/web/';
    }
    if (kDebugMode) {
      // 当前目录下的web文件夹
      noteDataPath = '${p.current}/note_data/';
    }
    init();
  }

  init() async {
    ip = (await intranetIpv4()).address;
    app.use(corsHeaders());
    app.get(
      '/',
      () => File('${webPath}index.html'),
    );
// 静态文件夹
    app.mount(
      '/css/',
      plus.createStaticHandler('$webPath/css/'),
    );
    app.mount(
      '/js/',
      plus.createStaticHandler('$webPath/js/'),
    );
    app.mount(
      '/notes/',
      plus.createStaticHandler('$noteDataPath/notes/'),
    );
    app.mount(
      '/images/',
      plus.createStaticHandler('$noteDataPath/images/'),
    );

    app.post('/save', (plus.Request request) async {
      // Map data = jsonDecode();
      var data = await request.body.asJson;
      String v4 = uuid.v4();
      String title = data['title'] == null || data['title'] == '' ? '未命名' : data['title'];
      late File file;
      String uuidStr = data['uuid'];
      // 新增
      if (data['uuid'] == '' || !File('$noteDataPath/notes/${data['uuid']}.txt').existsSync()) {
        uuidStr = v4;
        String path = '$v4.txt';
        file = File('$noteDataPath/notes/$path');
      } else {
        file = File('$noteDataPath/notes/$uuidStr.txt');
      }

      // if (file.existsSync()) {
      //   DateTime now = DateTime.now();
      //   path = '${now.hour}_${now.minute}_${now.second}_$title.txt';
      //   file = File('$noteDataPath/notes/$path');
      // }

      file.writeAsString(jsonEncode({'title': title, 'data': '${data['data']}'}));
      return plus.Response.ok(jsonEncode({'code': 0, 'msg': '保存成功', 'uuid': uuidStr}));
    });

    app.post('/getList', (plus.Request request) async {
      List list = [];
      for (var o in Directory('$noteDataPath/notes/').listSync()) {
        if (o.path.substring(o.path.lastIndexOf('.') + 1) == 'txt') {
          Map data = jsonDecode(File(o.path).readAsStringSync());
          data['uuid'] = o.path.substring(o.path.lastIndexOf('/') + 1, o.path.lastIndexOf('.'));
          list.add(data);
        }
      }
      return plus.Response.ok(jsonEncode({'code': 0, 'data': list}));
    });

    app.post('/delete', (plus.Request request) async {
      var data = await request.body.asJson;
      if (File('$noteDataPath/notes/${data['uuid']}.txt').existsSync()) {
        File('$noteDataPath/notes/${data['uuid']}.txt').deleteSync(recursive: true);
      }
      return plus.Response.ok(jsonEncode({'code': 0, 'data': ''}));
    });

    // post 上传文件
    app.post('/upload', (plus.Request request) async {
      if (!request.isMultipart) {
        return plus.Response.ok('Not a multipart request');
      } else if (request.isMultipartForm) {
        // final description = StringBuffer('Parsed form multipart request\n');
        await for (var formData in request.multipartFormData) {
          // description.writeln('${formData.name}: ${await formData.part.readString()}');

          if (formData.name == 'file') {
            String v4 = uuid.v4();
            String path = '${v4}_${formData.filename}';
            File file = File('$noteDataPath/images/$path');
            // 判断文件是否存在, 添加时间戳
            // if (await file.exists()) {
            //   DateTime now = DateTime.now();
            //   path = '${now.hour}_${now.minute}_${now.second}_${formData.filename}';
            //   file = File('$noteDataPath/images/$path');
            // }
            for (final chunk in await formData.part.toList()) {
              await file.writeAsBytes(chunk, mode: FileMode.append);
            }
            return plus.Response.ok(jsonEncode({'code': 0, 'path': path}));
          }
        }
        return plus.Response.ok("description.toString()");
      } else {
        final description = StringBuffer('Regular multipart request\n');
        await for (final part in request.parts) {
          description.writeln('new part');
          part.headers.forEach((key, value) => description.writeln('Header $key=$value'));
          final content = await part.readString();
          description.writeln('content: $content');
          description.writeln('end of part');
        }
        return plus.Response.ok(description.toString());
      }
    });
    await shelf_io.serve(app, ip, 8085);
    setState(() {});
  }

  clearImages() {
    BotToast.showLoading();
    List images = Directory('$noteDataPath/images').listSync();
    List txts = Directory('$noteDataPath/notes').listSync();
    String txtContent = '';
    for (var element in txts) {
      String path = element.path;
      if (path.substring(path.lastIndexOf('.') + 1) == 'txt') {
        txtContent += File(path).readAsStringSync();
      }
    }
    int count = 0;
    for (var image in images) {
      String path = image.path;
      if (['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'].contains(path.substring(path.lastIndexOf('.') + 1))) {
        if (!txtContent.contains(path.substring(path.lastIndexOf('\\') + 1))) {
          if (File(path).existsSync()) {
            File(path).deleteSync(recursive: true);
            count += 1;
          }
        }
      }
    }
    BotToast.closeAllLoading();
    BotToast.showText(text: '删除 $count 张图片');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          InkWell(
            onTap: () {
              launchUrl(Uri.parse('http://$ip:8085'));
            },
            child: Container(
              height: 32,
              alignment: Alignment.centerLeft,
              child: Text(
                '网站地址: http://$ip:8085',
              ),
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.green),
                  ),
                  onPressed: () async {
                    if (Directory('$noteDataPath/.git').existsSync()) {
                      var shell = Shell();
                      shell.run('start cmd /c ${noteDataPath}pull.cmd');
                    } else {
                      BotToast.showText(text: "需要配置git, 请查看文档", align: Alignment.center);
                    }
                  },
                  child: const Text("拉取Git数据"),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () async {
                    if (Directory('$noteDataPath/.git').existsSync()) {
                      var shell = Shell();
                      shell.run('start cmd /c ${noteDataPath}push.cmd');
                    } else {
                      BotToast.showText(text: "需要配置git, 请查看文档", align: Alignment.center);
                    }
                  },
                  child: const Text("推送Git数据"),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () async {
                    Shell().run('start "" "$noteDataPath"');
                  },
                  child: const Text("打开笔记目录"),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.red),
                  ),
                  onPressed: clearImages,
                  child: const Text("清理无用图片"),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
