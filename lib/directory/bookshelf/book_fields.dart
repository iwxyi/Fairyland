import 'package:fairyland/common/global.dart';
import 'package:fairyland/utils/file_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BookFields extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _BookFields();
  }
}

class _BookFields extends State<BookFields> {
  final formKey = GlobalKey<FormState>();
  bool isAutoValidate = false;
  Image coverImage = Image.asset('assets/covers/default.png');
  String coverPath;
  String name;
  String type;
  String author;
  bool isChanged = false;
  bool modifyModel = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: AppBar(title: Text('创建作品')),
        body: ListView(
          children: <Widget>[
            Card(
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).backgroundColor,
              elevation: 16,
              margin: EdgeInsets.all(16),
              semanticContainer: true,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: createForm(),
              ),
            ),
          ],
        ));
  }

  /// 创建小说的表单
  Widget createForm() {
    return Form(
      key: formKey,
      autovalidate: isAutoValidate,
      //      onWillPop: willPop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: () => selectCover(),
            child: getCoverImage(coverImage),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '书名 *'),
            keyboardType: TextInputType.text,
            validator: (value) {
              value = value.trim();
              if (value.isEmpty) {
                return '请输入作品名字';
              } else {
                Pattern pattern = r'^[\w\d@\-\._:?！ \u4e00-\u9fa5]+$';
                RegExp regex = new RegExp(pattern);
                if (!regex.hasMatch(value)) return '请输入正确的书名格式';
              }
              return null;
            },
            onSaved: (value) => name = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '风格'),
            keyboardType: TextInputType.text,
            onSaved: (value) => type = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: '作者'),
            keyboardType: TextInputType.text,
            onSaved: (value) => author = value,
          ),
          SizedBox(height: 10),
          FlatButton(
            onPressed: validateInputs,
            child: Text('创建'),
          )
        ],
      ),
    );
  }

  /// 获取封面控件
  Widget getCoverImage(Image image) {
    if (image == null) {
      return Column(
        children: <Widget>[
          new Image.asset('assets/covers/default.png'),
          Text("设置封面(建议200×300)")
        ],
      );
    } else {
      return image;
    }
  }

  /// 验证表单
  void validateInputs() {
    if (formKey.currentState.validate()) {
      formKey.currentState.save();

      if (modifyModel) {
        save();
      } else {
        if (create()) {
          // 创建成功，返回并切换
          Navigator.pop(context, name);
        }
      }
    } else {
      // 输入后再开启自动检查
      setState(() => isAutoValidate = true);
    }
  }

  /// 退出前是否提示
  Future<bool> willPop() {
    // 不知道为什么直接 pop 会导致返回的时候出错
    /*if (!isChanged) {
      Navigator.pop(context, true);
      return Future.value(true);
    }*/
    return showDialog(
          builder: (context) => AlertDialog(
            title: Text('您有修改未保存，确定退出当前页？'),
            actions: <Widget>[
              FlatButton(
                child: Text('No'),
                onPressed: () => Navigator.pop(context, false),
              ),
              FlatButton(
                child: Text('Yes'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
          context: context,
        ) ??
        false;
  }

  /// 获取新的封面
  void selectCover() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    coverPath = image.path;
    setState(() {
      coverImage = Image.file(image);
    });
  }

  /// 创建新的小说
  bool create() {
    if (name.isEmpty) {
      return false;
    }
    if (FileUtil.isDirExists('novels/' + name)) {
      return false;
    }

    // 创建默认的小说内容
    String path = Global.novelPath + name + "/";
    FileUtil.createDir(Global.novelPath);
    FileUtil.createDir(path);
    FileUtil.createDir(path + "chapters");
    
    File newCoverFile = File(path + 'cover.png');
    File oldCoverFile = File(coverPath);
    List<int> bytes = oldCoverFile.readAsBytesSync();
    newCoverFile.writeAsBytesSync(bytes);

    return true;
  }

  /// 保存修改的信息
  void save() {}
}
