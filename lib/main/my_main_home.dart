import 'file:///E:/Flutter/fairyland/lib/main/my_drawer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fairyland/square/square_page.dart';
import 'package:fairyland/directory/dir_page.dart';
import 'package:fairyland/editor/editor_page.dart';
import 'package:fairyland/assist/assist_page.dart';

import 'my_navigation_bar.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  List<PageBean> _pages = <PageBean>[
    PageBean(title: '目录', icon: Icons.list, widget: DirPage()),
    PageBean(title: '写作', icon: Icons.edit, widget: EditorPage()),
    PageBean(title: '助手', icon: Icons.school, widget: AssistPage()),
  ];
  PageController pageController;
  var currentPage = 0;
  TitledBottomNavigationBar bottomBar;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    bottomBar = new TitledBottomNavigationBar(
        items: _pages, controller: pageController,);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Widget _getAppBarTitle() {
    print('刷新标题' + pageController.page.toString());
    return _pages[0].widget.getAppBarTitle();
    //    return Text('这是什么神仙写作');
  }

  List<Widget> _getAppBarActions() {
    return _pages[0].widget.getAppBarActions();
    //    return <Widget>[];
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: AppBar(
//          title: _getAppBarTitle(),
//          actions: _getAppBarActions(),
        ),
        body: new PageView(
//          children: _pages.map((PageBean page) => page.widget).toList(),
          children: <Widget>[
            Container(
              color: Colors.grey.shade200,
            ),
            Container(
              color: Colors.redAccent,
            ),
            Container(
              color: Colors.blueAccent,
            ),
          ],
          controller: pageController,
          physics: BouncingScrollPhysics(),
          onPageChanged: (page) {
            setState((){
            
            });
          },
        ),
        drawer: MyDrawer(),
        bottomNavigationBar: bottomBar
    );
  }
}
