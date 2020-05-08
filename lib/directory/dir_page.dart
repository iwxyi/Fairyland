import 'dart:convert';
import 'package:fairyland/common/global.dart';
import 'package:fairyland/common/user_setting.dart';
import 'package:fairyland/directory/book_beans.dart';
import 'package:fairyland/directory/bookshelf/bookshelf.dart';
import 'package:fairyland/main/my_drawer.dart';
import 'package:fairyland/utils/file_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_beautiful_popup/main.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DirPage extends StatefulWidget {
  DirPage({Key key, this.openChapter}) : super(key: key);

  final openChapter;

  @override
  State<StatefulWidget> createState() {
    return new _DirPageState();
  }
}

enum ChapterActions {
  Rename,
  Insert,
  Delete,
  Restore,
  Publish,
  Information,
  MoveUp,
  MoveDown,
  MoveTop,
  MoveBottom
}

class _DirPageState extends State<DirPage> with AutomaticKeepAliveClientMixin {
  BookObject currentBook;
  List<VCItem> currentRoute = []; // 当前列表所在路径的id集合，一开始length =0
  List<VCItem> currentList; // 当前分卷下的子分卷/子章节的list

  bool _showDeletedItems = false;

  @override
  void initState() {
    super.initState();

    _initRecent();
  }

  @override
  bool get wantKeepAlive => true; // 保持滑动Tab的时候不重绘

  @override
  Widget build(BuildContext context) {
    // 通过重载 AutomaticKeepAliveClientMixin 的
    // wantKeepAlive 成员，使页面在切换 tab 时不重绘
    super.build(context);

    return new Scaffold(
//      drawer: MyDrawer.globalDrawer,
      appBar: new AppBar(
          leading: Builder(builder: (context) {
            return IconButton(
              icon: Icon(Icons.menu), //自定义图标
              onPressed: () { // 打开抽屉菜单
                G.rt.mainHomeKey.currentState.openDrawer();
              },
            );
          }),
          title: Builder(
            builder: (BuildContext context) {
              // 获取context后才能跳转页面
              return new InkWell(
                child: new Text(
                    currentBook == null ? '创建或切换作品' : currentBook.name),
                onTap: () {
                  actionOpenBookShelf();
                },
              );
            },
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.add),
              tooltip: '添加新章',
              onPressed: () => actionAppendChapter(),
            ),
            getBookMenu()
          ]),
      body: _getCatalogGroup(),
    );
  }

  /// 根据类型获取不同的列表
  Widget _getCatalogGroup() {
    if (G.us.bookCatalogMode == BookCatalogMode.Tree) {
      if (currentBook == null || currentBook.catalog == null) {
        return new Text('请创建作品');
      }
      // 树状模式
      var showedList = currentBook.catalog.where((element) => G.us.showCatalogRecycle || !element.deleted).toList();
      return ListView.builder(
        itemCount: showedList.length,
        itemBuilder: (context, index) {
          return _buildCatalogTreeTiles(showedList[index]);
        },
      );
    } else if (G.us.bookCatalogMode == BookCatalogMode.Flat) {
      // 显示单层模式
      return new Column(
        children: <Widget>[
          _buildCatalogFlatRouteView(),
          new Expanded(
            child: RefreshIndicator(
              onRefresh: actionSync,
              child: _buildCatalogFlatVCListView(),
            ),
          ),
        ],
      );
    } else {
      // 其他模式
      return Text("待开发的目录视图");
    }
  }

  /// 构建 Tree 模式的每一项
  Widget _buildCatalogTreeTiles(VCItem item) {
    /*if (!G.us.showCatalogRecycle && item.deleted) {
      return null;
    }*/
    if (item.isChapter()) {
      return _buildVolumeChapterTile(item);
    }
    
    // 分卷，构建树状列表
    return ExpansionTile(
      key: PageStorageKey<VCItem>(item),
      title: Text(item.getDisplayName()),
      children: item.vcList.where((element) => G.us.showCatalogRecycle || !element.deleted).toList().map(_buildCatalogTreeTiles).toList(),
      onExpansionChanged: (bool exp){
        if (exp) { // 展开
          currentList = item.vcList;
        } else { // 收起
          // 如果有父分卷，则聚焦至父分卷
          // 如果没有父分卷，则使用全书最外层分卷
          currentList = item.parent != null ? item.parent.vcList : currentBook.catalog;
        }
      },
    );
  }

  /// 获取 Flat 模式路径分割线的view
  Widget _buildCatalogFlatRouteView() {
    /*if (currentRoute == null || currentRoute.length == 0) {
      return new Padding(
        padding: EdgeInsets.only(bottom: 30),
      );
    }*/
    return new ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 24,
          maxHeight: 24,
        ),
        child: new Padding(
          padding: EdgeInsets.only(left: 16, top: 4),
          child: (currentRoute == null || currentRoute.length == 0)
              ? new Text(
                  '总字数：待统计',
                )
              : new ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: currentRoute.length + 1,
                  itemBuilder: (context, index) {
                    return InkWell(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8, right: 8),
                        child: index == 0
                            ? new Text(' / ')
                            : new Text(currentRoute[index - 1].name),
                      ),
                      onTap: () => actionEnterParentVolume(
                          index == 0 ? null : currentRoute[index - 1]),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return new Text(
                      '>',
                      style: TextStyle(color: new Color(0x88888888)),
                    );
                  },
                ),
        ));
  }

  /// 获取 Flat 模式下 ListView 整体
  /// 如果为空则显示一个添加按钮
  Widget _buildCatalogFlatVCListView() {
    if (currentBook == null) {
      return new Center(
          child: new InkWell(
        onTap: () {
          // todo: 点击出现俏皮晃头晃脑动画
        },
        child:
            new Text('↑ ↑ ↑\n请点击上方标题\n创建或切换作品', style: TextStyle(fontSize: 20)),
      ));
    }
    if (currentBook.catalog.length == 0) {
      return new Center(
          child: new InkWell(
        onTap: () => actionAppendChapter(),
        child: new Text('添加分卷', style: TextStyle(fontSize: 20)),
      ));
    }
    return AnimationLimiter(
      // 这个会报很多警告
      child: ListView.builder(
          itemCount: currentList.length,
          itemBuilder: (context, index) {
            return Offstage(
              offstage:
                  !_showDeletedItems && currentList[index].deleted ?? false,
              child: AnimationConfiguration.staggeredList(
                  position: index,
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: _buildVolumeChapterTile(currentList[index]),
                    ),
                  )),
            );
          }),
    );
    /*return ListView.separated(
      itemCount: currentList.length,
      itemBuilder: (BuildContext context, int index) {
        return _getVolumeChapterLine(currentList[index]);
      },
      separatorBuilder: (BuildContext context, int index) {
        return new Divider(height: 2);
      },
    );*/
  }

  /// 获取目录的每一行
  Widget _buildVolumeChapterTile(VCItem item) {
    String name = item.getDisplayName();
    Image image = Image.asset(item.isVolume()
        ? 'assets/icons/volume.png'
        : 'assets/icons/chapter.png');

    // 显示修改时间
    String timeDisplayed = '';
    if (item.modifyTime ?? 0 > 0) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      int delta = timestamp - item.modifyTime;
      if (delta < 60 * 1000) {
        // 一分钟以内
        timeDisplayed = '刚刚';
      } else if (delta < 60 * 60 * 1000) {
        // 一小时以内修改的
        timeDisplayed = (delta ~/ 60000).toString() + ' 分钟前';
      } else if (delta < 24 * 60 * 60 * 1000) {
        // 一天以内
        timeDisplayed = (delta ~/ 3600000).toString() + ' 小时前';
      } else {
        DateTime time = DateTime.fromMillisecondsSinceEpoch(item.modifyTime);
        timeDisplayed = time.toString();
      }
    }
    return new ListTile(
      leading: new Container(
        child: !item.deleted ? image : null,
        constraints: BoxConstraints(
            maxWidth: 32, minWidth: 32, minHeight: 32, maxHeight: 32),
      ),
      title: Row(
        children: <Widget>[
          !item.deleted
              ? new Text(name, style: TextStyle(fontSize: 16))
              : new Text(name,
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
          new Spacer(
            flex: 1,
          ),
          new Text(
            item.isVolume()
                ? ((item.vcList != null ? item.vcList.length.toString() : '?') +
                    ' 章')
                : (item.wordCount.toString() + ' 字'),
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
      subtitle: timeDisplayed.isNotEmpty ? new Text(timeDisplayed) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[getVCItemPopupMenuButton(item)],
      ),
      onTap: () {
        if (item.isVolume()) {
          actionEnterChildVolume(item);
        } else if (item.isChapter()) {
          openChapter(item);
        }
      },
      onLongPress: () => {},
    );
  }

  PopupMenuButton getVCItemPopupMenuButton(VCItem item) {
    return PopupMenuButton<ChapterActions>(
        icon: Icon(Icons.more_vert),
        itemBuilder: (BuildContext context) => item.isVolume()
            ? getVolumeActions(context, item)
            : getChapterActions(context, item),
        onSelected: (ChapterActions result) =>
            handleVCItemAction(item, result));
  }

  List<PopupMenuEntry<ChapterActions>> getVolumeActions(
      BuildContext context, VCItem item) {
    return <PopupMenuEntry<ChapterActions>>[
      const PopupMenuItem<ChapterActions>(
        child: Text('重命名'),
        value: ChapterActions.Rename,
      ),
      const PopupMenuItem<ChapterActions>(
        child: Text('插入章节'),
        value: ChapterActions.Insert,
      ),
      item.deleted
          ? const PopupMenuItem<ChapterActions>(
              child: Text('从回收站恢复'),
              value: ChapterActions.Restore,
            )
          : const PopupMenuItem<ChapterActions>(
              child: Text('移到回收站'),
              value: ChapterActions.Delete,
            ),
      PopupMenuItem<ChapterActions>(
        child: Text('上移'),
        value: ChapterActions.MoveUp,
        enabled: item.indexInList > 0,
      ),
      PopupMenuItem<ChapterActions>(
          child: Text('下移'),
          value: ChapterActions.MoveDown,
          enabled: item.indexInList <
              (item.parent == null
                      ? currentBook.catalog.length
                      : item.parent.vcList.length) -
                  1),
    ];
  }

  List<PopupMenuEntry<ChapterActions>> getChapterActions(
      BuildContext context, VCItem item) {
    return <PopupMenuEntry<ChapterActions>>[
      const PopupMenuItem<ChapterActions>(
        child: Text('重命名'),
        value: ChapterActions.Rename,
      ),
      const PopupMenuItem<ChapterActions>(
        child: Text('插入章节'),
        value: ChapterActions.Insert,
      ),
      const PopupMenuItem<ChapterActions>(
        child: Text('发布'),
        value: ChapterActions.Publish,
        enabled: false,
      ),
      const PopupMenuItem<ChapterActions>(
        child: Text('字数详情'),
        value: ChapterActions.Publish,
        enabled: false,
      ),
      item.deleted
          ? const PopupMenuItem<ChapterActions>(
              child: Text('从回收站恢复'),
              value: ChapterActions.Restore,
            )
          : const PopupMenuItem<ChapterActions>(
              child: Text('移到回收站'),
              value: ChapterActions.Delete,
            ),
      PopupMenuItem<ChapterActions>(
        child: Text('上移'),
        value: ChapterActions.MoveUp,
        enabled: item.indexInList > 0,
      ),
      PopupMenuItem<ChapterActions>(
          child: Text('下移'),
          value: ChapterActions.MoveDown,
          enabled: item.indexInList <
              (item.parent == null
                      ? currentBook.catalog.length
                      : item.parent.vcList.length) -
                  1),
    ];
  }

  void handleVCItemAction(VCItem item, ChapterActions result) {
    switch (result) {
      case ChapterActions.Rename:
        inputName('修改名字', item.isVolume() ? '卷名' : '章名', item.name,
            (String result) {
          setState(() {
            item.name = result;
            currentBook.setVCItemsContext();
            saveCatalog();
          });
        });
        break;
      case ChapterActions.Insert:
        inputName('插入章节', '章名', '', (String result) {
          int index = currentList.indexOf(item);
          if (index < 0) // 出错了，没找到
            return;
          _insertVCItemInCurrentList(
              index, new VCItem(name: result, type: VCItemType.ChapterType));
          currentBook.setVCItemsContext();
          saveCatalog();
        });
        break;
      case ChapterActions.Delete:
        setState(() {
            item.deleted = true;
            item.deleteTime = DateTime.now().millisecondsSinceEpoch;
            currentBook.setVCItemsContext();
            saveCatalog();
        });
        break;
      case ChapterActions.Restore:
        setState(() {
          item.deleted = false;
        });
        break;
      case ChapterActions.Publish:
        // TODO: Handle this case.
        break;
      case ChapterActions.Information:
        // TODO: Handle this case.
        break;
      case ChapterActions.MoveUp:
        setState(() {
          int index = currentList.indexOf(item);
          if (index <= 0) return;
          currentList.removeAt(index);
          int target = index - 1;
          if (!_showDeletedItems) {
            while (target > 0 && currentList[target].deleted) {
              target--;
            }
          }
          currentList.insert(target, item);
          currentBook.setVCItemsContext();
          saveCatalog();
        });
        break;
      case ChapterActions.MoveDown:
        setState(() {
          int index = currentList.indexOf(item);
          if (index < 0 || index >= currentList.length) return;
          currentList.removeAt(index);
          int target = index;
          if (!_showDeletedItems) {
            while (target < currentList.length && currentList[target].deleted) {
              target++;
            }
          }
          if (target >= currentList.length - 1)
            currentList.add(item);
          else
            currentList.insert(target + 1, item);
          currentBook.setVCItemsContext();
          saveCatalog();
        });
        break;
      case ChapterActions.MoveTop:
        setState(() {
          int index = currentList.indexOf(item);
          if (index < 0 || index >= currentList.length) return;
          currentList.removeAt(index);
          currentList.insert(0, item);
          currentBook.setVCItemsContext();
          saveCatalog();
        });
        break;
      case ChapterActions.MoveBottom:
        setState(() {
          int index = currentList.indexOf(item);
          if (index < 0 || index >= currentList.length) return;
          currentList.removeAt(index);
          currentList.add(item);
          currentBook.setVCItemsContext();
          saveCatalog();
        });
        break;
    }
  }

  PopupMenuButton getBookMenu() {
    if (currentBook == null) {
      return PopupMenuButton<String>(
        itemBuilder: (BuildContext content) => <PopupMenuItem<String>>[
          PopupMenuItem<String>(
            value: "book_shelf",
            child: Text('查看书架'),
          ),
        ],
        onSelected: (String value) {
          switch (value) {
            case 'book_shelf':
              actionOpenBookShelf();
              break;
          }
        },
      );
    }
    return PopupMenuButton<String>(
      itemBuilder: (BuildContext content) => <PopupMenuItem<String>>[
        PopupMenuItem<String>(
          value: "append_volume",
          child: Text('添加新卷'),
        ),
        PopupMenuItem<String>(
          value: "book_info",
          child: Text('全书统计'),
          enabled: false,
        ),
        PopupMenuItem<String>(
          value: "book_rename",
          child: Text('修改书名'),
        ),
        PopupMenuItem<String>(
          value: "book_export",
          child: Text('导出作品'),
          enabled: false,
        ),
        PopupMenuItem<String>(
          value: "book_duplicate",
          child: Text('复制作品'),
          enabled: false,
        ),
        PopupMenuItem<String>(
          value: "book_delete",
          child: Text('删除作品'),
        ),
        PopupMenuItem<String>(
          value: "book_settings",
          child: Text('目录设置'),
          enabled: false,
        ),
        PopupMenuItem<String>(
          value: "book_recycles",
          child: Text(_showDeletedItems ? '隐藏回收站' : '显示回收站'),
        ),
      ],
      onSelected: (String value) {
        switch (value) {
          case 'append_volume':
            actionAppendVolume();
            break;
          case 'book_recycles':
            setState(() {
              _showDeletedItems = !_showDeletedItems;
            });
            break;
          case 'book_delete':
            actionDeleteBook();
            break;
          default:
            {}
            break;
        }
      },
    );
  }

  void _initRecent() {
    // 恢复上次打开的作品
    String bookName = G.us.getConfig('recent/book_name', '');
    if (bookName.isNotEmpty && FileUtil.isDirExists(G.rt.bookPathD(bookName))) {
      openBook(bookName);
    }
  }

  void actionOpenBookShelf() {
    Navigator.push<String>(context,
        new MaterialPageRoute(builder: (BuildContext context) {
      return new Bookshelf();
    })).then((String result) {
      if (result == null || result.isEmpty) {
        // 按返回键返回是没有传回的参数的
        return;
      }

      // 读取作品
      closeCurrentBook();
      openBook(result);
    });
  }

  /// 从头打开作品
  /// 如果已经有打开的了，需要先调用 closeCurrentBook()
  void openBook(String name) {
    // 如果目录不存在或者文件有错误，弹出警告
    String path = G.rt.bookPathD(name);
    if (FileUtil.isDirNotExists(path) ||
        FileUtil.isFileNotExist(G.rt.bookCatalogPathD(name))) {
      Fluttertoast.showToast(
        msg: '无法读取作品：《' + name + '》所在数据',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
      );
      return;
    }

    // 读取作品目录
    G.rt.currentBookName = name;
    String str = FileUtil.readText(G.rt.cBookCatalogPathD());
    try {
      // 解析JSON
      currentBook = BookObject.fromJson(json.decode(str));
      currentBook.setVCItemsContext();
      currentList = currentBook.catalog;
    } catch (e) {
      Fluttertoast.showToast(msg: '解析目录树错误');
      currentList = [];
    } finally {
      currentRoute = [];
    }
    G.us.setConfig('recent/book_name', name);
    setState(() {});
  }

  /// 关闭当前一打开的作品
  /// 并且保存一些状态变量，以便下次打开时恢复
  void closeCurrentBook() {
    setState(() {
      G.rt.currentBookName = currentBook = null;
      currentRoute = null;
      currentList = null;
      G.us.setConfig('recent/book_name', '');
    });
  }

  /// 添加新的章节
  void actionAppendChapter() {
    if (currentBook == null) {
      Fluttertoast.showToast(msg: '请点击左上方标题创建一部作品');
      return;
    }

    // 添加新章
    inputName('添加新章', '章名', '', (String result) {
      // 添加章节到末尾
      _insertVCItemInCurrentList(
          -1, new VCItem(name: result, type: VCItemType.ChapterType));
      currentBook.setVCItemsContext();
      saveCatalog();
    });
  }

  /// 添加新的分卷
  void actionAppendVolume() {
    if (currentBook == null) {
      Fluttertoast.showToast(msg: '请点击左上方标题创建一部作品');
      return;
    }

    // 添加新卷
    inputName('添加新卷', '卷名', '', (String result) {
      // 添加分卷到末尾
      _insertVCItemInCurrentList(-1,
          new VCItem(name: result, type: VCItemType.VolumeType, vcList: []));
      currentBook.setVCItemsContext();
      saveCatalog();
    });
  }

  void _insertVCItemInCurrentList(int index, VCItem item) {
    if (currentBook == null) {
      Fluttertoast.showToast(msg: '请点击左上方标题创建一部作品');
      return;
    }
    if (item.id == null) {
      // 获取唯一ID
      item.id = currentBook.createRandomID();
      if (item.id.isEmpty) {
        Fluttertoast.showToast(msg: '章节过多，请将该需求反馈给开发者');
        return;
      }
    }
    if (item.isVolume() && item.vcList == null) {
      item.vcList = [];
    }
    if (index > 0 && index < currentList.length) {
      currentList.insert(index, item);
    } else {
      currentList.add(item);
    }
    setState(() {});
  }

  /// 获取当前查看的分卷
  /// 如果是根目录，返回 null
  VCItem getCurrentVolume() {
    if (currentRoute == null || currentRoute.length == 0) {
      return null;
    }
    return currentRoute.last;
  }

  /// 保存目录结构
  void saveCatalog() {
    if (currentBook == null) {
      return;
    }
    FileUtil.writeText(
        G.rt.cBookCatalogPathD(), jsonEncode(currentBook.toJson()));
  }

  /// 打开当前分卷下的子分卷
  void actionEnterChildVolume(VCItem volume) {
    if (currentBook == null) {
      return;
    }
    // 加到route末尾
    currentRoute.add(volume);
    _loadVolume(volume);
  }

  /// 打开上一层或者某一层的分卷
  void actionEnterParentVolume(VCItem volume) {
    if (currentBook == null) {
      return;
    }
    if (volume == null) {
      currentRoute = [];
      _loadVolume(null);
    } else if (currentRoute.length > 0 && currentRoute.last == volume) {
      // 如果打开的当前分卷，则相当于刷新
      _loadVolume(volume);
    } else {
      // 路径中，取消route后半部分
      while (currentRoute.length > 0) {
        if (currentRoute.last == volume) {
          break;
        }
        currentRoute.removeLast();
      }
      _loadVolume(volume);
    }
  }

  /// 加载某一分卷
  void _loadVolume(VCItem volume) {
    setState(() {
      // 如果是空的，则表示加载根目录
      if (volume == null) {
        currentList = currentBook.catalog;
      } else {
        currentList = volume.vcList;
      }
    });
  }

  /// 编辑器打开章节
  void openChapter(VCItem chapter) {
    widget.openChapter(chapter);
  }

  /// 下拉刷新，快捷云同步方式
  Future<void> actionSync() async {
    // 模拟延迟（现在还是什么都不做的）
    await Future.delayed(Duration(seconds: 1), () {
      setState(() {});
    });
  }

  /// 输入一行名字的操作（非空）
  void inputName(String title, String label, String def, var resultFunc) {
    var inputString = new TextEditingController();
    inputString.text = def;
    inputString.selection =
        new TextSelection(baseOffset: 0, extentOffset: def.length);
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: inputString,
              decoration: InputDecoration(
                hintText: def,
                hintMaxLines: 1,
                border: OutlineInputBorder(),
                labelText: label,
                prefixIcon: Icon(Icons.create),
              ),
              autofocus: true,
              onSubmitted: (value) {
                if (value != null && value.isNotEmpty) {
                  resultFunc(value.trim());
                  Navigator.of(context).pop();
                }
              },
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('确定'),
                onPressed: () {
                  if (inputString.text != null &&
                      inputString.text.trim().isNotEmpty) {
                    resultFunc(inputString.text);
                    Navigator.of(context).pop();
                  }
                },
              ),
              FlatButton(
                child: Text(
                  '取消',
                  style: TextStyle(color: Colors.grey),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  void actionRenameBook() {
    if (currentBook == null) {
      return;
    }
    inputName('修改书名', '书名', currentBook.name, (String result) {
      if (result == null || result.isEmpty) {
        return;
      }
      if (FileUtil.isDirExists(G.rt.bookPathD(result))) {
        Fluttertoast.showToast(msg: '作品《' + result + '》已存在');
        return;
      }
      if (!BookObject.canBeBookName(result)) {
        Fluttertoast.showToast(msg: '名字《' + result + '》包含特殊字符，无法用作书名');
        return;
      }
      // 修改书名
      currentBook.name = result;

      // 设置配置项
      G.us.setConfig('recent/book_name', result);
    });
  }

  /// 删除作品操作
  void actionDeleteBook() {
    if (currentBook == null) {
      return;
    }
    final popup = BeautifulPopup(
      context: context,
      template: TemplateFail,
    );
    final newColor = Colors.red.withOpacity(0.5);
    popup.recolor(newColor);
    popup.show(title: '警告', content: '是否删除该作品？\n\n将删除所有内容，不可恢复', actions: [
      popup.button(
          label: '我已想好，确定删除',
          onPressed: () {
            _deleteCurrentBook();
            Navigator.of(context).pop();
          })
    ]);
  }

  /// 删除作品
  _deleteCurrentBook() {
    String name = currentBook.name.toString();
    closeCurrentBook();

    FileUtil.createDir(G.rt.recyclesBooksPath);
    String bookPath = G.rt.booksPath + name;
    String recyclePath = G.rt.rBookPath(name);
    int index = 0;
    String tempPath = recyclePath;
    while (FileUtil.isDirExists(tempPath)) {
      tempPath = recyclePath + '(' + (++index).toString() + ')';
    }
    if (index > 0) recyclePath = tempPath;
    FileUtil.moveDir(bookPath, recyclePath);
  }
}
