import 'package:fairyland/assist/assist_page.dart';
import 'package:fairyland/common/global.dart';
import 'package:fairyland/common/runtime_info.dart';
import 'package:fairyland/common/user_setting.dart';
import 'package:fairyland/directory/book_beans.dart';
import 'package:fairyland/directory/bookshelf/bookshelf.dart';
import 'package:fairyland/editor/chatper_editor.dart';
import 'package:fairyland/main/my_drawer.dart';
import 'package:fairyland/setting/app_setting_item_bean.dart';
import 'package:fairyland/setting/app_setting_factory.dart';
import 'package:flutter/material.dart';
import 'package:fairyland/directory/dir_page.dart';
import 'package:fairyland/editor/editor_page.dart';

import 'my_navigation_bar.dart';

class MyHomePage extends StatefulWidget {
	MyHomePage({Key key, this.title}) : super(key: key) {
		G.rt.mainHomeKey = key;
	}
	
	final String title;
	
	@override
	_MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
		with SingleTickerProviderStateMixin {
	final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
	
	DirPage dirPage;
	EditorPage editorPage;
	AssistPage assistPage;
	
	ChapterEditor chapterEditor;
	
	List<PageBean> _pages;
	PageController pageController;
	static const dirPageIndex = 0;
	static const editorPageIndex = 1;
	static const assistPageIndex = 2; // ignore: unused_field
	var currentPage = dirPageIndex;
	
	TitledBottomNavigationBar bottomBar;
	
	@override
	void initState() {
		super.initState();
		
		// 初始化界面
		_initPages();
		
		// 初始化所有可修改设置项
		(new AppSettingFactory(G.rt, G.us)).initAppSettingItems();
		
		// 恢复上次使用的内容
		_restoreRecent();
	}
	
	/// 初始化各种控件界面
	void _initPages() {
		/// 上次使用的页面
		int pageIndex = 0;
		if (G.us.restartPageIndex == RestartPageIndex.Auto) {
			pageIndex = G.us.getInt('recent/main_page', 0);
		} else {
			pageIndex = G.us.restartPageIndex.index - 1;
		}
		G.rt.mainPageIndex = pageIndex;
		
		pageController = PageController(initialPage: pageIndex);
		
		dirPage = new DirPage(
			openBookCallback: _openBookCallback,
			renameBookCallback: _renameBookCallback,
			closeBookCallback: _closeBookCallback,
			openChapterCallback: _openChapterCallback,
			renameChapterCallback: _renameChapterCallback,
			deleteChapterCallback: _deleteChapterCallback,
		);
		editorPage = new EditorPage();
		assistPage = new AssistPage();
		chapterEditor = editorPage.chapterEditor;
		_pages = <PageBean>[
			PageBean(title: '目录', icon: Icons.list, widget: dirPage),
			PageBean(title: '写作', icon: Icons.edit, widget: editorPage),
			PageBean(title: '助手', icon: Icons.school, widget: assistPage),
		];
		
		bottomBar = new TitledBottomNavigationBar(
			items: _pages,
			controller: pageController,
		);
	}
	
	/// 恢复上次使用的数据
	/// 让用户觉得没有彻底关闭似的
	void _restoreRecent() {
	
	}
	
	@override
	void dispose() {
		pageController.dispose();
		super.dispose();
	}
	
	@override
	Widget build(BuildContext context) {
		G.rt.mainHomeKey = _scaffoldKey;
		return new Scaffold(
				key: _scaffoldKey,
				body: new PageView(
					children: _pages.map((PageBean page) => page.widget).toList(),
					controller: pageController,
					physics: BouncingScrollPhysics(),
					onPageChanged: (page) {
						setState(() {
							currentPage = page;
							G.us.setConfig('recent/main_page', page);
						});
					},
				),
				drawer: new MyDrawer(),
				bottomNavigationBar: bottomBar);
	}
	
	void _openBookCallback(BookObject book) {}
	
	void _renameBookCallback(BookObject book) {}
	
	void _closeBookCallback(BookObject book) {}
	
	/// 打开章节
	void _openChapterCallback(VCItem chapter) {
		setState(() {
			pageController.animateToPage(editorPageIndex,
					duration: Duration(milliseconds: 300), curve: Curves.easeOutQuad);
			editorPage.openChapter(chapter);
			if (editorPage.myState != null) {
				editorPage.myState.setState(() {});
			}
		});
	}
	
	/// 重命名章节 callback
	void _renameChapterCallback(VCItem chapter) {
		// 如果是正在编辑的章节
		if (editorPage.currentChapter == chapter) {}
	}
	
	/// 删除章节 callback
	void _deleteChapterCallback(VCItem chapter) {
		// 如果是正在编辑的章节
		if (editorPage.currentChapter == chapter) {
			editorPage.closeChapter();
		}
	}
}
