// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:ogaku/share/share.dart';
import 'package:ogaku/share/config.dart' show Config;

import 'package:ogaku/models/data/announcement.dart' show AnnouncementAdapter;
import 'package:ogaku/models/data/attendances.dart' show AttendanceAdapter, AttendanceTypeAdapter;
import 'package:ogaku/models/data/class.dart' show ClassAdapter;
import 'package:ogaku/models/data/classroom.dart' show ClassroomAdapter;
import 'package:ogaku/models/data/event.dart' show EventAdapter, EventCategoryAdapter;
import 'package:ogaku/models/data/grade.dart' show GradeAdapter;
import 'package:ogaku/models/data/lesson.dart' show LessonAdapter;
import 'package:ogaku/models/data/messages.dart' show MessagesAdapter, MessageAdapter;
import 'package:ogaku/models/data/student.dart' show StudentAdapter, AccountAdapter;
import 'package:ogaku/models/data/teacher.dart' show TeacherAdapter;
import 'package:ogaku/models/data/timetables.dart'
    show TimetablesAdapter, TimetableDayAdapter, TimetableLessonAdapter, SubstitutionDetailsAdapter;
import 'package:ogaku/models/data/unit.dart' show UnitAdapter, LessonRangesAdapter;
import 'package:ogaku/models/provider.dart' show ProviderDataAdapter;

import 'package:ogaku/interface/material/sessions_page.dart' as materialapp show sessionsPage;
import 'package:ogaku/interface/cupertino/sessions_page.dart' as cupertinoapp show sessionsPage;

Future<void> main() async {
  if (Platform.isAndroid) WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive
    ..registerAdapter(AnnouncementAdapter())
    ..registerAdapter(AttendanceAdapter())
    ..registerAdapter(AttendanceTypeAdapter())
    ..registerAdapter(ClassAdapter())
    ..registerAdapter(ClassroomAdapter())
    ..registerAdapter(EventAdapter())
    ..registerAdapter(EventCategoryAdapter())
    ..registerAdapter(GradeAdapter())
    ..registerAdapter(LessonAdapter())
    ..registerAdapter(MessagesAdapter())
    ..registerAdapter(MessageAdapter())
    ..registerAdapter(StudentAdapter())
    ..registerAdapter(AccountAdapter())
    ..registerAdapter(TeacherAdapter())
    ..registerAdapter(TimetablesAdapter())
    ..registerAdapter(TimetableDayAdapter())
    ..registerAdapter(TimetableLessonAdapter())
    ..registerAdapter(SubstitutionDetailsAdapter())
    ..registerAdapter(UnitAdapter())
    ..registerAdapter(LessonRangesAdapter())
    ..registerAdapter(ProviderDataAdapter())
    ..registerAdapter(SessionsDataAdapter())
    ..registerAdapter(SessionAdapter());

  // TODO you'll know what to do with this... when time comes.
  await Share.settings.load();
  Share.session = Share.settings.sessions.lastSession ?? Session(providerGuid: 'PROVGUID-SHIM-SMPL-FAKE-DATAPROVIDER');

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  StatefulWidget Function() child = Config.useCupertino ? () => cupertinoapp.sessionsPage : () => materialapp.sessionsPage;
  bool subscribed = false;

  @override
  Widget build(BuildContext context) {
    if (!subscribed) {
      Share.changeBase.subscribe((args) {
        setState(() {
          if (args != null) child = args.value;
        });
      });
      subscribed = true;
    }

    return child();
  }
}
