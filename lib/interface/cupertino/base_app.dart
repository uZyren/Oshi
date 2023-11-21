// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:io';

import 'package:darq/darq.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:format/format.dart';
import 'package:oshi/share/appcenter.dart';
import 'package:oshi/share/notifications.dart';
import 'package:oshi/share/translator.dart';
import 'package:path/path.dart' as path;

import 'package:oshi/interface/cupertino/pages/home.dart' show homePage;
import 'package:oshi/interface/cupertino/pages/grades.dart' show gradesPage;
import 'package:oshi/interface/cupertino/pages/timetable.dart' show timetablePage;
import 'package:oshi/interface/cupertino/pages/messages.dart' show messagesPage;
import 'package:oshi/interface/cupertino/pages/absences.dart' show absencesPage;
import 'package:oshi/share/share.dart';
import 'package:show_fps/show_fps.dart';
import 'package:url_launcher/url_launcher.dart';

// Boiler: returned to the main application
StatefulWidget get baseApp => BaseApp();

class BaseApp extends StatefulWidget {
  const BaseApp({super.key});

  @override
  State<BaseApp> createState() => _BaseAppState();
}

class _BaseAppState extends State<BaseApp> {
  CupertinoTabController tabController = CupertinoTabController();

  @override
  void initState() {
    super.initState();

    // Set up a filesystem watcher
    if (kDebugMode && Platform.isWindows) {
      File(path.join(Directory.current.path, 'assets/resources/strings')).watch().listen(
          (event) => Share.translator.loadResources(Share.settings.config.languageCode).then((value) => setState(() {})));
    }

    // Set up other stuff after the app's launched
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Share.checkUpdates.broadcast(); // Check for updates
      NotificationController.requestNotificationAccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-subscribe to all events - navigation
    Share.tabsNavigatePage.unsubscribeAll();
    Share.tabsNavigatePage.subscribe((args) {
      if (args?.value == null) return;
      setState(() => tabController.index = args!.value.clamp(0, 4));
    });

    // Re-subscribe to all events - refresh
    Share.refreshBase.unsubscribeAll();
    Share.refreshBase.subscribe((args) => setState(() {}));

    return CupertinoApp(
        theme: _eventfulColorTheme,
        debugShowCheckedModeBanner: false,
        home: Builder(builder: (context) {
          // Re-subscribe to all events - update
          Share.checkUpdates.unsubscribeAll();
          Share.checkUpdates.subscribe((args) => _checkforUpdates(context));

          return ShowFPS(
              alignment: Alignment.topLeft,
              visible: Share.settings.config.devMode,
              showChart: Share.settings.config.devMode,
              borderRadius: BorderRadius.all(Radius.circular(11)),
              child: Builder(builder: (context) {
                // Re-subscribe to all events - modals
                Share.showErrorModal.unsubscribeAll();
                Share.showErrorModal.subscribe((args) async {
                  if (args?.value == null) return;
                  await showCupertinoModalPopup(
                      context: context,
                      useRootNavigator: true,
                      builder: (s) => CupertinoActionSheet(
                          title: Text(args!.value.title),
                          message: Text(args.value.message),
                          actions: args.value.actions.isEmpty
                              ? null
                              : args.value.actions.entries
                                  .select(
                                    (x, index) => CupertinoActionSheetAction(
                                      child: Text(x.key),
                                      onPressed: () {
                                        try {
                                          x.value();
                                        } catch (ex) {
                                          // ignored
                                        }
                                        Navigator.of(context, rootNavigator: true).pop();
                                      },
                                    ),
                                  )
                                  .toList()));
                });

                return CupertinoTabScaffold(
                  controller: tabController,
                  tabBar: CupertinoTabBar(
                      backgroundColor: CupertinoTheme.of(context).barBackgroundColor.withAlpha(0xFF),
                      items: [
                        BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: '/Titles/Pages/Home'.localized),
                        BottomNavigationBarItem(icon: Icon(CupertinoIcons.rosette), label: '/Titles/Pages/Grades'.localized),
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.calendar), label: '/Titles/Pages/Schedule'.localized),
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.envelope), label: '/Titles/Pages/Messages'.localized),
                        BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.person_crop_circle_badge_minus),
                            label: '/Titles/Pages/Absences'.localized),
                      ]),
                  tabBuilder: (context, index) => CupertinoTabView(
                    builder: (context) => switch (index) {
                      0 => homePage,
                      1 => gradesPage,
                      2 => timetablePage,
                      3 => messagesPage,
                      4 => absencesPage,
                      _ => homePage,
                    },
                  ),
                );
              }));
        }));
  }

  void _showAlertDialog(BuildContext context, Uri url) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('/BaseApp/Update/AlertHeader'.localized),
        content: Text('/BaseApp/Update/Alert'.localized.format(Platform.isAndroid ? 'Android' : 'iOS')),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await launchUrl(url);
              } catch (ex) {
                // ignored
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _checkforUpdates(BuildContext context) {
    AppCenter.checkForUpdates().then((value) {
      if (value.result) _showAlertDialog(context, value.download);
    }).catchError((ex) {});
  }

  CupertinoThemeData get _eventfulColorTheme {
    // Halloween colors
    if (DateTime.now().month == DateTime.october && DateTime.now().day == 31) {
      return CupertinoThemeData(primaryColor: CupertinoColors.systemOrange);
    }
    // St. Peter day colors
    if (DateTime.now().month == DateTime.july && DateTime.now().day == 12) {
      return CupertinoThemeData(primaryColor: CupertinoColors.systemGreen);
    }
    // Christmas colors
    if (DateTime.now().month == DateTime.december &&
        (DateTime.now().day == 24 || DateTime.now().day == 25 || DateTime.now().day == 26)) {
      return CupertinoThemeData(primaryColor: CupertinoColors.systemRed);
    }
    // Default colors - should be changeable through settings
    return CupertinoThemeData(primaryColor: Share.settings.config.cupertinoAccentColor.color);
  }
}
