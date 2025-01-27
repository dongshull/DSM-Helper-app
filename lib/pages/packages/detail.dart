import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:dsm_helper/pages/packages/uninstall.dart';
import 'package:dsm_helper/util/function.dart';
import 'package:dsm_helper/widgets/cupertino_image.dart';
import 'package:dsm_helper/widgets/label.dart';
import 'package:dsm_helper/widgets/neu_back_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:neumorphic/neumorphic.dart';

class PackageDetail extends StatefulWidget {
  final Map package;
  final bool beta;
  final String method;
  PackageDetail(this.package, {this.beta = false, this.method});
  @override
  _PackageDetailState createState() => _PackageDetailState();
}

class _PackageDetailState extends State<PackageDetail> {
  String thumbnailUrl = "";
  String installVolume = "";
  String installPath = "";
  List volumes = [];
  double installProgress = 0;
  bool installing = false;
  Timer timer;
  String taskId = "";
  String installButtonText = "安装";
  @override
  void initState() {
    if (widget.package['installed'] && widget.package['additional'] != null) {
      setState(() {
        installPath = widget.package['additional']['installed_info']['path'].split("/@appstore")[0];
        if (widget.package['additional']['installed_info']['path'].contains("volume")) {
          List paths = widget.package['additional']['installed_info']['path'].split("/");
          installVolume = paths[1];
        } else {
          installVolume = "系统分区";
        }
      });
    }
    if (widget.package['can_update']) {
      setState(() {
        installButtonText = "更新";
      });
    }
    thumbnailUrl = widget.package['thumbnail'].last;
    if (!thumbnailUrl.startsWith("http")) {
      thumbnailUrl = Util.baseUrl + thumbnailUrl;
    }
    getVolumes();
    super.initState();
  }

  getVolumes() async {
    var res = await Api.volumes();
    if (res['success']) {
      setState(() {
        volumes = res['data']['volumes'];
      });
      if (widget.method == "install") {
        selectVolume();
      } else if (widget.method == "update") {
        update();
      }
    }
  }

  Widget _buildSwiperItem(String url) {
    if (!url.startsWith("http")) {
      url = Util.baseUrl + url;
    }
    return CupertinoExtendedImage(
      url,
      height: 210,
      fit: BoxFit.contain,
    );
  }

  selectVolume() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: NeuCard(
            width: double.infinity,
            bevel: 20,
            curveType: CurveType.emboss,
            decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      "选择套件安装位置",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(
                      height: 12,
                    ),
                    ...volumes.map((volume) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: NeuButton(
                          onPressed: () async {
                            install(volume['volume_path']);
                            Navigator.of(context).pop();
                          },
                          decoration: NeumorphicDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          bevel: 20,
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            padding: EdgeInsets.only(left: 20),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${volume['display_name']}(可用容量：${Util.formatSize(int.parse(volume['size_free_byte']))}) - ${volume['fs_type']}"),
                                SizedBox(
                                  height: 5,
                                ),
                                Text(
                                  "${volume['description']}",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    NeuButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                      },
                      decoration: NeumorphicDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      bevel: 20,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "取消",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  getLaunchedPackages() async {
    widget.package['launched'] = true;
    widget.package['can_update'] = false;
  }

  update() async {
    setState(() {
      installButtonText = "请稍后";
    });
    var res = await Api.installPackageQueue(widget.package['id'], widget.package['version'], beta: widget.beta);
    if (res['success']) {
      if (res['data']['paused_pkgs'].length > 0) {
        showCupertinoModalPopup(
          context: context,
          builder: (context) {
            return Material(
              color: Colors.transparent,
              child: NeuCard(
                width: double.infinity,
                bevel: 5,
                curveType: CurveType.emboss,
                decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          "确认更新",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          '更新${res['data']['cause_pausing_pkgs'].join(",")}时，${res['data']['paused_pkgs'].join("，")}将被停用。',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                        ),
                        SizedBox(
                          height: 22,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: NeuButton(
                                onPressed: () async {
                                  install(installPath);
                                  Navigator.of(context).pop();
                                },
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                bevel: 5,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  "继续更新",
                                  style: TextStyle(fontSize: 18, color: Colors.redAccent),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 16,
                            ),
                            Expanded(
                              child: NeuButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                },
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                bevel: 5,
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  "取消",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ).then((value) {
          setState(() {
            installButtonText = "更新";
          });
        });
      } else {
        install(installPath);
      }
    }
  }

  uninstallPackage() async {
    var res = await Api.uninstallPackageTask(widget.package['id']);
    if (res['success']) {
      Util.toast("卸载成功");
      Navigator.of(context).pop();
    } else {
      Util.toast("套件卸载失败，错误代码：${res['error']['code']}");
    }
  }

  install(path) async {
    var res = await Api.installPackageTask(widget.package['id'], path);
    print(res);
    if (res['success']) {
      Util.toast("已开始安装");
      setState(() {
        installing = true;
        installButtonText = "准备安装…";
        installProgress = double.parse(res['data']['progress']);
      });
      //进度
      timer = Timer.periodic(Duration(seconds: 5), (timer) {
        Api.installPackageStatus(res['data']['taskid']).then((value) {
          print(value);
          setState(() {
            installing = !value['data']['finished'];
            if (value['data']['finished']) {
              widget.package['installed'] = true;
              getLaunchedPackages();
              timer.cancel();
            } else if (value['data']['progress'] != null) {
              if (value['data']['progress'] is double) {
                installProgress = value['data']['progress'];
              } else {
                installProgress = double.parse(value['data']['progress']);
              }
              installButtonText = "下载中:${installProgress.toStringAsFixed(2)}%";
            } else if (value['data']['status'] == "installing") {
              installButtonText = "安装中…";
            } else if (value['data']['status'] == 'upgrading') {
              installButtonText = "更新中…";
            }
          });
        });
      });
    } else if (res['error']['code'] == 4501) {
      Util.toast("此套件需配置信息，当前暂不支持，请在WEB端安装");
    } else {
      Util.toast("安装套件失败，代码${res['error']['code']}");
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(context),
        title: Text(
          "${widget.package['dname']}",
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                NeuCard(
                  curveType: CurveType.flat,
                  bevel: 20,
                  decoration: NeumorphicDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CupertinoExtendedImage(
                          thumbnailUrl,
                          width: 60,
                        ),
                        SizedBox(
                          width: 20,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${widget.package['dname']}"),
                              if (widget.package['installed'])
                                Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: widget.package['launched'] ? Label("已启动", Colors.green) : Label("已停用", Colors.red),
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                if (widget.package['snapshot'] != null && widget.package['snapshot'].length > 0)
                  NeuCard(
                    margin: EdgeInsets.only(top: 20),
                    curveType: CurveType.flat,
                    bevel: 20,
                    decoration: NeumorphicDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 210,
                            child: Swiper(
                              autoplay: true,
                              autoplayDelay: 5000,
                              pagination: SwiperPagination(alignment: Alignment.bottomCenter, builder: DotSwiperPaginationBuilder(activeColor: Colors.lightBlueAccent, size: 7, activeSize: 7)),
                              itemCount: widget.package['snapshot'].length,
                              itemBuilder: (context, i) {
                                return _buildSwiperItem(widget.package['snapshot'][i]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                NeuCard(
                  margin: EdgeInsets.only(top: 20),
                  curveType: CurveType.flat,
                  bevel: 20,
                  decoration: NeumorphicDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "描述",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text("${widget.package['desc']}"),
                      ],
                    ),
                  ),
                ),
                if (widget.package['changelog'] != "")
                  NeuCard(
                    margin: EdgeInsets.only(top: 20),
                    curveType: CurveType.flat,
                    bevel: 20,
                    decoration: NeumorphicDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${widget.package['version']}新增功能",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          // SizedBox(
                          //   height: 20,
                          // ),
                          Html(
                            data: widget.package['changelog'],
                            onLinkTap: (link, _, __, ___) {
                              AndroidIntent intent = AndroidIntent(
                                action: 'action_view',
                                data: link,
                                arguments: {},
                              );
                              intent.launch();
                            },
                            style: {
                              "ol": Style(
                                padding: EdgeInsets.zero,
                                margin: Margins.zero,
                              ),
                              "li": Style(),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                NeuCard(
                  margin: EdgeInsets.only(top: 20),
                  curveType: CurveType.flat,
                  bevel: 20,
                  decoration: NeumorphicDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "其他信息",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: [
                            NeuCard(
                              width: (MediaQuery.of(context).size.width - 100) / 2,
                              curveType: CurveType.flat,
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              bevel: 20,
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("开发者"),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  if (widget.package['maintainer_url'] != null && widget.package['maintainer_url'] != "")
                                    GestureDetector(
                                      child: Text(
                                        "${widget.package['maintainer']}",
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                      onTap: () {
                                        AndroidIntent intent = AndroidIntent(
                                          action: 'action_view',
                                          data: widget.package['maintainer_url'],
                                          arguments: {},
                                        );
                                        intent.launch();
                                      },
                                    )
                                  else
                                    Text(
                                      "${widget.package['maintainer']}",
                                    ),
                                ],
                              ),
                            ),
                            if (widget.package['distributor'] != null && widget.package['distributor'] != "")
                              NeuCard(
                                width: (MediaQuery.of(context).size.width - 100) / 2,
                                curveType: CurveType.flat,
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                bevel: 20,
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("发布人员"),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    if (widget.package['distributor_url'] != null && widget.package['distributor_url'] != "")
                                      GestureDetector(
                                        child: Text(
                                          "${widget.package['distributor']}",
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                        onTap: () {
                                          AndroidIntent intent = AndroidIntent(
                                            action: 'action_view',
                                            data: widget.package['distributor_url'],
                                            arguments: {},
                                          );
                                          intent.launch();
                                        },
                                      )
                                    else
                                      Text(
                                        "${widget.package['distributor']}",
                                      ),
                                  ],
                                ),
                              ),
                            NeuCard(
                              width: (MediaQuery.of(context).size.width - 100) / 2,
                              curveType: CurveType.flat,
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              bevel: 20,
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("下载次数"),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Text("${widget.package['download_count']}"),
                                ],
                              ),
                            ),
                            if (widget.package['installed'])
                              NeuCard(
                                width: (MediaQuery.of(context).size.width - 100) / 2,
                                curveType: CurveType.flat,
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                bevel: 20,
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("已安装版本"),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Text("${widget.package['installed_version']}"),
                                  ],
                                ),
                              ),
                            if (widget.package['installed'])
                              NeuCard(
                                width: (MediaQuery.of(context).size.width - 100) / 2,
                                curveType: CurveType.flat,
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                bevel: 20,
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("安装位置"),
                                    SizedBox(
                                      height: 5,
                                    ),
                                    Text("${installVolume.replaceAll("volume", "存储空间 ")}"),
                                  ],
                                ),
                              ),
                            NeuCard(
                              width: (MediaQuery.of(context).size.width - 100) / 2,
                              curveType: CurveType.flat,
                              decoration: NeumorphicDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              bevel: 20,
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("最新版本"),
                                  SizedBox(
                                    height: 5,
                                  ),
                                  Text("${widget.package['version']}"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: Row(
              children: [
                if (widget.package['installed']) ...[
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: NeuButton(
                        onPressed: () async {
                          if (widget.package['additional']['is_uninstall_pages']) {
                            Navigator.of(context).push(CupertinoPageRoute(
                                builder: (context) {
                                  return UninstallPackage(widget.package);
                                },
                                settings: RouteSettings(name: "uninstall_package")));
                          } else {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (context) {
                                return Material(
                                  color: Colors.transparent,
                                  child: NeuCard(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(22),
                                    bevel: 5,
                                    curveType: CurveType.emboss,
                                    decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                                    child: SafeArea(
                                      top: false,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                            "卸载套件",
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                          ),
                                          SizedBox(
                                            height: 12,
                                          ),
                                          Text(
                                            "确认要卸载此套件？",
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                                          ),
                                          SizedBox(
                                            height: 22,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: NeuButton(
                                                  onPressed: () async {
                                                    Navigator.of(context).pop();
                                                    uninstallPackage();
                                                  },
                                                  decoration: NeumorphicDecoration(
                                                    color: Theme.of(context).scaffoldBackgroundColor,
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  bevel: 5,
                                                  padding: EdgeInsets.symmetric(vertical: 10),
                                                  child: Text(
                                                    "卸载",
                                                    style: TextStyle(fontSize: 18, color: Colors.redAccent),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              Expanded(
                                                child: NeuButton(
                                                  onPressed: () async {
                                                    Navigator.of(context).pop();
                                                  },
                                                  decoration: NeumorphicDecoration(
                                                    color: Theme.of(context).scaffoldBackgroundColor,
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  bevel: 5,
                                                  padding: EdgeInsets.symmetric(vertical: 10),
                                                  child: Text(
                                                    "取消",
                                                    style: TextStyle(fontSize: 18),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                        padding: EdgeInsets.symmetric(vertical: 15),
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          "卸载",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  if (widget.package['launched'] && widget.package['additional'] != null && widget.package['additional']['startable'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: widget.package['launched']
                            ? NeuButton(
                                onPressed: () {
                                  showCupertinoModalPopup(
                                    context: context,
                                    builder: (context) {
                                      return Material(
                                        color: Colors.transparent,
                                        child: NeuCard(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(22),
                                          bevel: 5,
                                          curveType: CurveType.emboss,
                                          decoration: NeumorphicDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                                          child: SafeArea(
                                            top: false,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                Text(
                                                  "停用套件",
                                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                                ),
                                                SizedBox(
                                                  height: 12,
                                                ),
                                                Text(
                                                  "确认要停用此套件？",
                                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
                                                ),
                                                SizedBox(
                                                  height: 22,
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: NeuButton(
                                                        onPressed: () async {
                                                          Navigator.of(context).pop();
                                                          var res = await Api.launchPackage(widget.package['id'], widget.package['dsm_apps'], "stop");
                                                          if (res['success']) {
                                                            Util.toast("已停用");
                                                            setState(() {
                                                              widget.package['launched'] = false;
                                                            });
                                                          }
                                                        },
                                                        decoration: NeumorphicDecoration(
                                                          color: Theme.of(context).scaffoldBackgroundColor,
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        bevel: 5,
                                                        padding: EdgeInsets.symmetric(vertical: 10),
                                                        child: Text(
                                                          "停用",
                                                          style: TextStyle(fontSize: 18, color: Colors.redAccent),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 20,
                                                    ),
                                                    Expanded(
                                                      child: NeuButton(
                                                        onPressed: () async {
                                                          Navigator.of(context).pop();
                                                        },
                                                        decoration: NeumorphicDecoration(
                                                          color: Theme.of(context).scaffoldBackgroundColor,
                                                          borderRadius: BorderRadius.circular(25),
                                                        ),
                                                        bevel: 20,
                                                        padding: EdgeInsets.symmetric(vertical: 10),
                                                        child: Text(
                                                          "取消",
                                                          style: TextStyle(fontSize: 18),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                padding: EdgeInsets.symmetric(vertical: 15),
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text("停用"),
                              )
                            : NeuButton(
                                onPressed: () async {
                                  var res = await Api.launchPackage(widget.package['id'], widget.package['dsm_apps'], "start");
                                  print(res);
                                  if (res['success']) {
                                    Util.toast("已启动");
                                    setState(() {
                                      widget.package['launched'] = true;
                                    });
                                  }
                                },
                                padding: EdgeInsets.symmetric(vertical: 15),
                                decoration: NeumorphicDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text("启动"),
                              ),
                      ),
                    ),
                ] else
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: NeuButton(
                        onPressed: () {
                          selectVolume();
                        },
                        padding: EdgeInsets.symmetric(vertical: 15),
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text("$installButtonText"),
                      ),
                    ),
                  ),
                if (widget.package['can_update'])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: NeuButton(
                        onPressed: () async {
                          update();
                          // install(volume['volume_path']);
                        },
                        padding: EdgeInsets.symmetric(vertical: 15),
                        decoration: NeumorphicDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text("$installButtonText"),
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
