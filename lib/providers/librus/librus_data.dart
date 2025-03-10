// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:event/src/event.dart';
import 'package:event/src/eventargs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';
import 'package:oshi/models/data/averages.dart';
import 'package:oshi/models/data/messages.dart';
import 'package:oshi/share/extensions.dart';
import 'package:oshi/share/platform.dart';
import 'package:oshi/models/progress.dart';
import 'package:darq/darq.dart';

import 'package:oshi/providers/librus/reader/reader_stub.dart'
    if (dart.library.io) 'package:oshi/providers/librus/reader/reader_io.dart'
    if (dart.library.js) 'package:oshi/providers/librus/reader/reader_web.dart';

import 'package:oshi/models/data/attendances.dart' as models;
import 'package:oshi/models/data/lesson.dart' as models;
import 'package:oshi/models/data/student.dart' as models;
import 'package:oshi/models/data/teacher.dart' as models;
import 'package:oshi/models/data/timetables.dart' as models;
import 'package:oshi/models/data/class.dart' as models;
import 'package:oshi/models/data/unit.dart' as models;
import 'package:oshi/models/data/classroom.dart' as models;
import 'package:oshi/models/data/announcement.dart' as models;
import 'package:oshi/models/data/event.dart' as models;
import 'package:oshi/models/data/grade.dart' as models;
import 'package:oshi/models/data/messages.dart' as models;
import 'package:oshi/models/provider.dart' as models;
import 'package:oshi/share/translator.dart';

import 'models/shim/classrooms.dart' show Classrooms, Classroom;
import 'models/shim/event_categories.dart' show EventCategories;
import 'models/shim/free_day_types.dart' show FreeDayTypes;
import 'models/shim/grade_categories.dart' show GradeCategories;
import 'models/shim/grade_comments.dart' show GradeComments;
import 'models/shim/homework_categories.dart' show HomeworkCategories;
import 'models/shim/lessons.dart' show Lessons;
import 'models/shim/messages_users.dart' show MessagesUsers;
import 'models/shim/subjects.dart' show Subjects, Subject;
import 'models/shim/users.dart' show Users, User;
import 'models/shim/virtual_classes.dart' show VirtualClasses, VirtualClass;
import 'models/shim/attendances.dart' show Attendances;
import 'models/shim/me.dart' show Me;
import 'models/shim/student_class.dart' show StudentClass;
import 'models/shim/student_unit.dart' show DateTimeExtension, StudentUnit;
import 'models/shim/schools.dart' show Schools, School;
import 'models/shim/timetables.dart' show Timetables;
import 'models/shim/school_notices.dart' show SchoolNotices;
import 'models/shim/home_works.dart' show HomeWorks, Category;
import 'models/shim/parent_teacher_conferences.dart' show ParentTeacherConferences;
import 'models/shim/teacher_free_days.dart' show TeacherFreeDays;
import 'models/shim/homework_assignments.dart' show HomeWorkAssignments;
import 'models/shim/free_days.dart' show SchoolFreeDays;
import 'models/shim/class_free_days.dart' show ClassFreeDays;
import 'models/shim/grades.dart' show Grades;
import 'models/shim/inbox_messages.dart' show InboxMessages, InboxMessage;
import 'models/shim/outbox_messages.dart' show OutboxMessages, OutboxMessage, MessageToSend, Receivers, Schoolreceiver;

class LibrusDataReader implements models.IProvider {
  models.ProviderData dataChunk = models.ProviderData();
  SynergiaData? data;

  @override
  Future<({Exception? message, bool success})> login(
      {Map<String, String>? credentials, IProgress<({double? progress, String? message})>? progress}) async {
    data = SynergiaData(); // Reset

    progress?.report((progress: 0.1, message: 'D870CFEB-F16B-4091-9084-9620E5BACE22'.localized));

    // Grab our credentials from the map
    var username = credentials?['login'];
    var password = credentials?['pass'];
    var proxy = credentials?['proxy'];

    // Check the provided proxy URL if running on web
    if (kIsWeb && Uri.tryParse(proxy ?? '') == null)
      return (success: false, message: Exception('1DBA54DA-C4D2-4D21-B072-89AAFCC4758D'.localized));
    else
      data = SynergiaData(credentials?['proxy'] ?? ''); // Reset again

    // Instantiate a portal login
    progress?.report((progress: 0.2, message: '440FA18A-AD7D-47B4-B4FF-C2FE934479DA'.localized));
    data?.synergiaLogin = LibrusLogin(synergiaData: data, login: username, pass: password, proxyUrl: proxy);

    // Check whether there is data to log in with
    if ((username?.isEmpty ?? true) || (password?.isEmpty ?? true))
      return (success: false, message: Exception('E15B042C-B7C1-43AB-9557-EA1B1F08CE9C'.localized));

    // Validate the credentials and extract the API token
    progress?.report((progress: 0.3, message: '395B01AF-19EE-43BE-880D-1EAE925B33C2'.localized));
    await data!.synergiaLogin!.setupToken(progress: progress);

    // Create a new instance of the portal API scraper
    data?.librusApi = LibrusReader(data!);

    // Still here? That's good news!
    return (success: true, message: null);
  }

  @override
  Future<({Exception? message, bool success})> refresh(
      {DateTime? weekStart, IProgress<({String? message, double? progress})>? progress}) async {
    if (data?.librusApi == null) throw Exception('C5FDD0D8-771D-4DCE-8FCE-62D1BA4A6C93'.localized);

//#region Basics

    // Cache other data to access it faster (the API is shit and splits everything)
    var lessonsShim = Lessons.fromJson(await data!.librusApi!.request("Lessons"));
    var subjectsShim = Subjects.fromJson(await data!.librusApi!.request("Subjects"));
    var teachersShim = Users.fromJson(await data!.librusApi!.request("Users"));
    var classroomsShim = Classrooms.fromJson(await data!.librusApi!.request("Classrooms"));
    var gradeCategoriesShim = GradeCategories.fromJson(await data!.librusApi!.request("Grades/Categories"));
    var gradeCommentsShim = GradeComments.fromJson(await data!.librusApi!.request("Grades/Comments"));
    var eventCategoriesShim = EventCategories.fromJson(await data!.librusApi!.request("HomeWorks/Categories"));
    var freeDayCategoriesShim = FreeDayTypes.fromJson(await data!.librusApi!.request("ClassFreeDays/Types"));
    var classesShim = VirtualClasses.fromJson(await data!.librusApi!.request("VirtualClasses"));
    var homeworkCatgShim = HomeworkCategories.fromJson(await data!.librusApi!.request("HomeWorkAssignments/Categories"));

    var timetableShim = weekStart != null
        ? Timetables.fromJson(await data!.librusApi!.request(
            "Timetables?weekStart=${DateFormat('y-M-d').format(weekStart.subtract(Duration(days: weekStart.weekday - 1)))}"))
        : Timetables.fromJson(await data!.librusApi!.request('Timetables'));

    try {
      // Refresh for the next week too, if possible
      timetableShim.timetable.addAll((weekStart != null
              ? Timetables.fromJson(await data!.librusApi!.request(
                  "Timetables?weekStart=${DateFormat('y-M-d').format(weekStart.add(const Duration(days: 7)).subtract(Duration(days: weekStart.weekday - 1)))}"))
              : Timetables.fromJson(await data!.librusApi!.request(
                  "Timetables?weekStart=${DateFormat('y-M-d').format((DateTime.now().add(const Duration(days: 7))).subtract(Duration(days: DateTime.now().weekday - 1)))}")))
          .timetable);
    } catch (ex) {
      // ignored
    }
//#endregion

    progress?.report((progress: 0.1, message: '9395EE9D-253E-4795-9F7D-DFA49D161EA8'.localized));

//#region Attendance

    // Attendance list - unorganized attendance entries, parse by days, type, and lessons
    var attendancesShim = Attendances.fromJson(await data!.librusApi!.request("Attendances"));
    var attendance = attendancesShim.attendances?.select((x, index) => models.Attendance(
        addDate: x.addDate ?? DateTime.now(),
        date: x.date ?? DateTime.now(),
        lessonNo: x.lessonNo,
        type: x.type!.id.asAttendance(),
        teacher: teachersShim.users?.firstWhereOrDefault((element) => element.id == (x.addedBy?.id ?? -1))?.asTeacher(),
        lesson: models.TimetableLesson(
            lessonNo: x.lessonNo,
            subject: subjectsShim.subjects!
                .firstWhereOrDefault((subject) =>
                    subject.id ==
                    lessonsShim.lessons!.firstWhereOrDefault((lesson) => lesson.id == x.lesson!.id)?.subject!.id)
                ?.asSubject(),
            teacher: teachersShim.users?.firstWhereOrDefault((element) => element.id == (x.addedBy?.id ?? -1))?.asTeacher(),
            date: x.date ?? DateTime.now())));

//#endregion

    progress?.report((progress: 0.2, message: '4C6CC778-B7FE-4B76-BE87-BCFC9E1E2F7B'.localized));

//#region Student

    // Get shared student data
    var studentShim = Me.fromJson(await data!.librusApi!.request('Me'));
    var sClassShim = StudentClass.fromJson(await data!.librusApi!.request('Classes/${studentShim.me!.meClass!.id}'));
    var sUnitShim = StudentUnit.fromJson(await data!.librusApi!.request('Units/${sClassShim.studentClassClass!.unit!.id}'));
    var sSchoolShim = Schools.fromJson(await data!.librusApi!.request('Schools'));

    teachersShim.users?.where((x) => x.id == sClassShim.studentClassClass?.classTutor?.id).forEach((element) {
      element.isHomeTeacher = true;
    });

    var sHomeTeacher = teachersShim.users!
        .firstWhere((x) => x.isHomeTeacher,
            orElse: () => User(id: -1, firstName: 'Unknown', lastName: 'Unknown', isEmployee: false, groupId: -1))
        .asTeacher();

    var mainStudentClass = sClassShim.asClass(sUnitShim.asUnit(sSchoolShim.school!), sHomeTeacher);
    var virtualClasses = classesShim.virtualClasses?.select((element, index) => element.asClass(mainStudentClass)).toList();

    // Student - the user account, including (most) unit and (some) school data
    var student = models.Student(
        account: models.Account(
            id: studentShim.me!.account!.id,
            userId: studentShim.me!.account!.userId,
            number: ((await data!.librusApi!.request('Users/${studentShim.me!.account!.userId}'))['User']
                    ?['ClassRegisterNumber'] as int?) ??
                0,
            firstName: studentShim.me!.account!.firstName,
            lastName: studentShim.me!.account!.lastName),
        mainClass: mainStudentClass,
        virtualClasses: virtualClasses,
        userCode: '${mainStudentClass.unit.id}${mainStudentClass.unit.fullName.firstLettersName}_${mainStudentClass.unit.town}:${data?.synergiaLogin?.synergiaLogin}'
            .toLowerCase(),
        teamCodes: [mainStudentClass.teamCodePair]
            .appendAllIf(
                virtualClasses?.select((x, _) => x.teamCodePair).toList() ?? [], virtualClasses?.isNotEmpty ?? false)
            .toMap((x) => x),
        attendances: attendance?.toList(),
        subjects: lessonsShim.lessons!
            .groupBy((x) => x.subject?.id)
            .where((x) => x.key != null)
            .select((x, index) =>
                x.firstWhereOrDefault(
                    (y) => timetableShim.timetable.values.any((z) => z.any((w) => w?.any((a) => a.teacher?.id == y.teacher?.id.toString()) ?? false)),
                    defaultValue: x.first) ??
                x.first)
            .select((x, index) {
          var lessonData = subjectsShim.subjects!.firstWhereOrDefault((y) => y.id == x.subject!.id);
          return models.Lesson(
            id: x.subject!.id,
            url: x.subject!.url,
            name: lessonData?.name ?? 'Unknown',
            no: lessonData?.no ?? 0,
            short: lessonData?.short ?? 'Unknwn',
            isExtracurricular: lessonData?.isExtracurricular ?? false,
            isBlockLesson: lessonData?.isBlockLesson ?? false,
            hostClass: mainStudentClass,
            teacher: teachersShim.users!.firstWhereOrDefault((y) => y.id == x.teacher!.id)?.asTeacher(),
            grades: null,
          );
        }).toList());

    try {
      // Check the lucky number (if exists)
      var luckyNumberData = (await data!.librusApi!.request('LuckyNumbers'));

      var forToday = (DateTime.tryParse(luckyNumberData["LuckyNumber"]?["LuckyNumberDay"]) ?? DateTime(2000))
          .isSameDate(DateTime.now());
      var forTomorrow = (DateTime.tryParse(luckyNumberData["LuckyNumber"]?["LuckyNumberDay"]) ?? DateTime(2000))
          .isSameDate(DateTime.now().add(const Duration(days: 1)));

      student.mainClass.unit.luckyNumber = // Check whether the date for the lucky number result is "today"
          (forToday || forTomorrow)
              ? (luckyNumberData["LuckyNumber"]?["LuckyNumber"])
              : null; // Parsing the lucky number date has failed

      if (!forToday && forTomorrow) student.mainClass.unit.luckyNumberTomorrow = true;
    } catch (ex) {
      // ignore
    }

//#endregion

    progress?.report((progress: 0.3, message: '65F39C72-B55D-4970-986B-69DDA8135FF7'.localized));

//#region Timetable

    // Timetable - the timetable, including classrooms, teacher names, subjects
    var timetable = models.Timetables(
        timetable: timetableShim.timetable.map((key, value) => MapEntry(
            DateTime.parse(key),
            models.TimetableDay(
                lessons: value.select(
              (lessons, index) {
                return lessons
                    ?.select((lesson, index) => models.TimetableLesson(
                          url: lesson.lesson?.url ?? '',
                          lessonNo: int.tryParse(lesson.lessonNo) ?? -1,
                          isCanceled: lesson.isCanceled,
                          modifiedSchedule: lesson.isSubstitutionClass,
                          substitutionNote: '',

                          date: DateTime.parse(key),
                          hourFrom: lesson.hourFrom.asTime(),
                          hourTo: lesson.hourTo.asTime(),

                          lessonClass: student.mainClass.id == lesson.timetableLessonClass?.id
                              ? student.mainClass // Either the regular or virtual one
                              : classesShim.virtualClasses
                                  ?.firstWhereOrDefault((y) => y.id == lesson.virtualClass?.id)
                                  ?.asClass(student.mainClass),
                          classroom: classroomsShim.classrooms
                              ?.firstWhereOrDefault((y) => y.id == int.tryParse(lesson.classroom?.id ?? ''))
                              ?.asClassroom(),

                          subject: subjectsShim.subjects
                              ?.firstWhereOrDefault((y) => y.id == int.tryParse(lesson.subject?.id ?? ''))
                              ?.asSubject(),
                          teacher: teachersShim.users
                              ?.firstWhereOrDefault((y) => y.id == int.tryParse(lesson.teacher?.id ?? ''))
                              ?.asTeacher(),

                          substitutionDetails: lesson.isSubstitutionClass
                              ? models.SubstitutionDetails(
                                  originalUrl: '',
                                  originalLessonNo:
                                      int.tryParse(lesson.orgLessonNo ?? '') ?? int.tryParse(lesson.newLessonNo ?? '') ?? 0,
                                  originalDate: lesson.orgDate ?? lesson.newDate ?? DateTime.now(),
                                  originalHourFrom: lesson.orgHourFrom?.asTime(lesson.orgDate) ??
                                      lesson.newHourFrom?.asTime(lesson.newDate) ??
                                      DateTime.now(),
                                  originalHourTo: lesson.orgHourTo?.asTime(lesson.orgDate) ??
                                      lesson.newHourTo?.asTime(lesson.newDate) ??
                                      DateTime.now(),
                                  originalClassroom: lesson.orgClassroom?.id != null
                                      ? classroomsShim.classrooms!
                                          .firstWhereOrDefault((y) => y.id == int.tryParse(lesson.orgClassroom?.id ?? ''))
                                          ?.asClassroom()
                                      : lesson.newClassroom?.id != null
                                          ? classroomsShim.classrooms!
                                              .firstWhereOrDefault(
                                                  (y) => y.id == int.tryParse(lesson.newClassroom?.id ?? ''))
                                              ?.asClassroom()
                                          : null,
                                  originalSubject: lesson.orgSubject?.id != null
                                      ? subjectsShim.subjects!
                                          .firstWhereOrDefault((y) => y.id == int.tryParse(lesson.orgSubject?.id ?? ''))
                                          ?.asSubject()
                                      : lesson.newSubject?.id != null
                                          ? subjectsShim.subjects!
                                              .firstWhereOrDefault((y) => y.id == int.tryParse(lesson.newSubject?.id ?? ''))
                                              ?.asSubject()
                                          : null,
                                  originalTeacher: lesson.orgTeacher?.id != null
                                      ? teachersShim.users!
                                          .firstWhereOrDefault((y) => y.id == int.tryParse(lesson.orgTeacher?.id ?? ''))
                                          ?.asTeacher()
                                      : lesson.newTeacher?.id != null
                                          ? teachersShim.users!
                                              .firstWhereOrDefault((y) => y.id == int.tryParse(lesson.newTeacher?.id ?? ''))
                                              ?.asTeacher()
                                          : null,
                                )
                              : null, // Don't provide any details for 'normal' lessons
                        ))
                    .toList();
              },
            ).toList()))));

//#endregion

    progress?.report((progress: 0.4, message: '8966023D-0F77-4B9D-B31B-385A201EB05A'.localized));

//#region Notices and Agenda

    // Read all announcements (school notices) - generic notices
    student.mainClass.unit.announcements = SchoolNotices.fromJson(await data!.librusApi!.request('SchoolNotices'))
        .schoolNotices
        ?.select((x, index) => models.Announcement(
              id: -1,
              url: x.id,
              read: x.wasRead,
              subject: x.subject,
              content: x.content,
              contact:
                  teachersShim.users!.firstWhereOrDefault((y) => y.id == x.addedBy?.id, defaultValue: null)?.asTeacher(),
              startDate: x.startDate ?? DateTime.now(),
              endDate: x.endDate ?? DateTime.now(),
            ))
        .toList();

    // Read all agenda events (home works) - tests, other events
    student.mainClass.events = HomeWorks.fromJson(await data!.librusApi!.request('HomeWorks'))
            .homeWorks
            ?.select((x, index) => models.Event(
                id: x.id,
                lessonNo: int.tryParse(x.lessonNo ?? ''),
                date: x.date,
                addDate: x.addDate,
                timeFrom: x.timeFrom.asTime(x.date),
                timeTo: x.timeTo.asTime(x.date),
                content: x.content,
                category: x.category?.asEvent() ?? models.EventCategory.other,
                categoryName: x.category?.asEvent() == null
                    ? eventCategoriesShim.categories!
                            .firstWhereOrDefault((y) => y.id == x.category?.id, defaultValue: null)
                            ?.name ??
                        ''
                    : '',
                sender:
                    teachersShim.users!.firstWhereOrDefault((y) => y.id == x.createdBy?.id, defaultValue: null)?.asTeacher(),
                classroom: classroomsShim.classrooms!
                    .firstWhereOrDefault((y) => y.id == x.classroom?.id, defaultValue: null)
                    ?.asClassroom()))
            .toList() ??
        [];

    // Read all parent-teacher meetings
    addOrReplace(
        student.mainClass.events,
        ParentTeacherConferences.fromJson(await data!.librusApi!.request('ParentTeacherConferences'))
                .parentTeacherConferences
                ?.select((x, index) => models.Event(
                    id: x.id,
                    date: x.date,
                    timeFrom: x.time.asTime(x.date),
                    content: x.topic,
                    category: models.EventCategory.conference,
                    sender: teachersShim.users!
                        .firstWhereOrDefault((y) => y.id == x.teacher?.id, defaultValue: null)
                        ?.asTeacher(),
                    classroom: classroomsShim.classrooms!
                        .firstWhereOrDefault((y) => y.name == x.room, defaultValue: null)
                        ?.asClassroom()))
                .toList() ??
            []);

    // Read all agenda events (home works) - tests, other events
    // addOrReplace(
    //     student.mainClass.events,
    //     TeacherFreeDays.fromJson(await data!.librusApi!.request('TeacherFreeDays'))
    //             .teacherFreeDays
    //             ?.where((x) =>
    //                 !(teachersShim.users?.firstWhereOrDefault((y) => y.id == x.teacher?.id)?.lastName.contains('Wakat') ??
    //                     true))
    //             .select((x, index) => models.Event(
    //                 id: x.id,
    //                 timeFrom: x.dateFrom?.withTime(x.timeFrom?.asTime()) ?? DateTime.now(),
    //                 timeTo: x.dateTo?.withTime(x.timeTo?.asTime()) ?? DateTime.now(),
    //                 category: models.EventCategory.teacher,
    //                 content: '',
    //                 sender: teachersShim.users!.firstWhereOrDefault((y) => y.id == x.teacher?.id)?.asTeacher()))
    //             .toList() ??
    //         []);

//#endregion

    progress?.report((progress: 0.5, message: '166B3D1B-90DF-446D-87F6-B27BF62D2C23'.localized));

//#region Homeworks

    // Read all agenda events (home works) - tests, other events
    addOrReplace(
        student.mainClass.events,
        (await HomeWorkAssignments.fromJson(await data!.librusApi!.request('HomeWorkAssignments'))
                    .homeWorkAssignments
                    ?.select((x, index) async => models.Event(
                        id: x.id,
                        addDate: x.date,
                        timeFrom: x.date ?? DateTime.now(),
                        timeTo: x.dueDate,
                        title: x.topic,
                        content: x.text,
                        done: x.studentsWhoMarkedAsDone?.isNotEmpty ?? false,
                        category: models.EventCategory.homework,
                        categoryName: homeworkCatgShim.categories!
                                .firstWhereOrDefault((y) => y.id == x.category?.id, defaultValue: null)
                                ?.categoryName ??
                            '',
                        sender: teachersShim.users!.firstWhereOrDefault((y) => y.id == x.teacher?.id)?.asTeacher(),
                        attachments: (await x.homeworkAssigmentFiles?.select((y, index) async {
                              var url = (await data!.librusApi!
                                      .request('HomeWorkAssignments/Attachment/${x.id}-${y["Id"]}'))['DownloadUrl']
                                  ?.toString();
                              return models.Attachment(
                                  name: y['Name']?.toString(),
                                  location: (url?.contains('GetFile') ?? false) ? '$url/get' : url);
                            }).awaitAll())
                                ?.toList() ??
                            []))
                    .awaitAll())
                ?.toList() ??
            []);

//#endregion

    progress?.report((progress: 0.6, message: 'A081AE97-83F2-4B70-98E6-1654A12455C5'.localized));

//#region Free Days

    SchoolFreeDays.fromJson(await data!.librusApi!.request('SchoolFreeDays')).schoolFreeDays?.forEach((x) {
      timetable.timetable.entries
          .where((day) => day.key.isAfterOrSame(x.dateFrom) && day.key.isBeforeOrSame(x.dateTo))
          .forEach((y) {
        y.value.lessons.clear();

        addOrReplaceItem(
            student.mainClass.events,
            models.Event(
                id: x.id,
                date: y.key,
                timeFrom: x.dateFrom ?? DateTime.now(),
                timeTo: x.dateTo,
                content: x.name,
                category: models.EventCategory.freeDay));
      });
    });

    ClassFreeDays.fromJson(await data!.librusApi!.request('ClassFreeDays'))
        .classFreeDays
        ?.where((x) =>
            x.classFreeDayClass?.id == student.mainClass.id ||
            (student.virtualClasses?.any((c) => c.id == x.virtualClass?.id) ?? false))
        .forEach((x) {
      timetable.timetable.entries
          .where((day) => day.key.isAfterOrSame(x.dateFrom) && day.key.isBeforeOrSame(x.dateTo))
          .forEach((y) {
        y.value.lessons.removeWhere((tLessons) => // Remove all free days' lessons
            y.value.lessons.indexOf(tLessons) >= (x.lessonNoFrom ?? 100) &&
            y.value.lessons.indexOf(tLessons) <= (x.lessonNoTo ?? -1));

        addOrReplaceItem(
            student.mainClass.events,
            models.Event(
                id: x.id,
                date: y.key,
                timeFrom: x.dateFrom ?? DateTime.now(),
                timeTo: x.dateTo,
                category: models.EventCategory.freeDay,
                content: freeDayCategoriesShim.types?.firstWhereOrDefault((element) => element.id == x.type?.id)?.name ??
                    'Lekcja odwołana',
                categoryName:
                    freeDayCategoriesShim.types?.firstWhereOrDefault((element) => element.id == x.type?.id)?.name ?? ''));
      });
    });

//#endregion

    progress?.report((progress: 0.7, message: '10B640EC-6CBF-42CF-A20B-7CA5E97E8AFE'.localized));

//#region Free Days

    var gradesResult = Grades.fromJson(await data!.librusApi!.request('Grades')).grades;
    var resits = (gradesResult
        ?.where((x) => (x.resit is Map<String, dynamic> && x.resit["Id"] is int))
        .selectMany((x, index) => [x.id, x.resit["Id"] as int]))?.appendAll(gradesResult
            ?.where((x) => (x.improvement is Map<String, dynamic> && x.improvement["Id"] is int))
            .selectMany((x, index) => [x.id, x.improvement["Id"] as int]) ??
        []);

    // Push all grades to their respective subjects within our student object
    gradesResult?.forEach((x) {
      var category = gradeCategoriesShim.categories?.firstWhereOrDefault((y) => y.id == x.category?.id);
      var subject = student.subjects.firstWhereOrDefault((y) => y.id == x.subject?.id, defaultValue: null);
      subject?.grades.add(models.Grade(
          id: x.id,
          url: '',
          name: category?.name ?? 'No category',
          value: x.grade,
          weight: category?.weight ?? 0,
          comments: x.comments
                  ?.select((comment, index) =>
                      gradeCommentsShim.comments?.firstWhereOrDefault((y) => y.id == comment.id, defaultValue: null)?.text ??
                      '')
                  .toList() ??
              [],
          countsToAverage: category?.countToTheAverage ?? false,
          date: x.date ?? DateTime.now(),
          addDate: x.addDate ?? DateTime.now(),
          addedBy: teachersShim.users!.firstWhereOrDefault((y) => y.id == x.addedBy?.id)?.asTeacher(),
          resitPart: resits?.contains(x.id) ?? false,
          semester: x.semester,
          isConstituent: x.isConstituent,
          isSemester: x.isSemester,
          isSemesterProposition: x.isSemesterProposition,
          isFinal: x.isFinal,
          isFinalProposition: x.isFinalProposition));
    });

//#endregion

    progress?.report((progress: 0.8, message: '3543FC9A-32FB-446F-8CB8-FEF95248CD2C'.localized));
    dataChunk.student = student; // Push the data to the outer scope, add or update
    dataChunk.timetables = timetable; // Push the data to the outer scope, add only

    try {
      var averagesRaw = await data!.librusApi!.synergiaRequest(
          'uczen/graph_ajax.php?type=wykres_sredniej&classId=${mainStudentClass.id}&userId=${studentShim.me?.account?.userId}');

      Map<String, dynamic> averages = jsonDecode(
          '{ ${RegExp('(?<=chartDataGradeAverangeGraphDiv = \\[)((.|\n)*?)(?=\\];)').allMatches(averagesRaw).first.group(1)} }'
              .replaceAll('{ columnGradeAverangeGraphDiv:', '')
              .replaceAll('",\n', '": {')
              .replaceAll('x0:', '"student":')
              .replaceAll('x1:', '"class":')
              .replaceAll('\n', ''));

      dataChunk.student.mainClass.averages.clear();
      dataChunk.student.mainClass.averages.addEntries(averages.entries.select((x, _) => MapEntry(
          DateTime(int.parse(x.key.split('-')[0]), int.parse(x.key.split('-')[1])),
          Averages(
            student: x.value["student"] * 1.0,
            level: x.value["class"] * 1.0,
          ))));
    } catch (ex) {
      // ignored
    }

    return (success: true, message: null);
  }

  @override
  Future<({Exception? message, bool success})> refreshMessages(
      {IProgress<({String? message, double? progress})>? progress}) async {
    progress?.report((progress: 0.1, message: '135991AA-5B53-42EA-8A2B-5406B249CC40'.localized));

//#region Basics

    // Cache other data to access it faster (the API is shit and splits everything)
    var teachersShim = Users.fromJson(await data!.librusApi!.request("Users"));

    try {
      var messagesUsers =
          MessagesUsers.fromJson(await data!.librusApi!.messagesRequest("receivers/groups/school-employees"));

      teachersShim.users
          ?.where((user) => messagesUsers.receivers?.any((receiver) => receiver.userIdInt == user.id) ?? false)
          .forEach((user) {
        user.userId =
            messagesUsers.receivers!.firstWhereOrDefault((receiver) => receiver.userIdInt == user.id)?.accountIdInt;
      });
    } catch (ex) {
      // ignored
    }

//#endregion

    progress?.report((progress: 0.9, message: '75A471A9-DA5B-4C1D-B078-6B57988F9244'.localized));

//#region Messages

    // Copy all valid message users to the shared list
    dataChunk.messages =
        Messages(receivers: teachersShim.users!.where((x) => x.userId != null).select((x, index) => x.asTeacher()).toList());

    // Fetch all received messages (list), set up data handlers
    dataChunk.messages.received = InboxMessages.fromJson(await data!.librusApi!.messagesRequest('inbox/messages'))
            .data
            ?.select((x, index) => models.Message(
                id: int.tryParse(x.messageId) ?? -1,
                url: '',
                topic: x.topic,
                preview: x.content.tryBase64Decoded(),
                hasAttachments: x.isAnyFileAttached,
                sendDate: x.sendDate ?? DateTime.now(),
                readDate: x.readDate,
                sender: teachersShim.users!
                        .firstWhereOrDefault((user) => user.nameInv == x.senderName, defaultValue: null)
                        ?.asTeacher() ??
                    models.Teacher(firstName: x.senderName)))
            .toList() ??
        [];

    // Fetch all sent messages (list), set up data handlers
    dataChunk.messages.sent = OutboxMessages.fromJson(await data!.librusApi!.messagesRequest('outbox/messages'))
            .data
            ?.select((x, index) => models.Message(
                id: int.tryParse(x.messageId) ?? -1,
                url: '',
                topic: x.topic,
                sendDate: x.sendDate ?? DateTime.now(),
                preview: x.content.tryBase64Decoded(),
                hasAttachments: false,
                receivers: [models.Teacher(firstName: x.receiverName)]))
            .toList() ??
        [];

//#endregion

    return (success: true, message: null);
  }

  @override
  Future<({Exception? message, bool success})> sendMessage(
      {required List<models.Teacher> receivers, required String topic, required String content}) async {
    try {
      return (
        success: (await data?.librusApi?.messagesPost(
                'messages',
                MessageToSend(
                        topic: base64.encode(utf8.encode(topic)),
                        content: base64.encode(utf8.encode(content)),
                        receivers: Receivers(
                            schoolReceivers: receivers
                                .select((x, index) => Schoolreceiver(accountId: x.userId?.toString() ?? ''))
                                .toList()))
                    .toJson()))?['data']?['status'] ==
            'sent',
        message: null
      );
    } on Exception catch (e) {
      // Emotional damage!
      return (success: false, message: e);
    }
  }

  @override
  Event<Value<String>> propertyChanged = Event<Value<String>>();

  @override
  models.ProviderData? get registerData => dataChunk;

  @override
  String get providerName => 'Librus\u00AE Synergia';

  @override
  String get providerDescription =>
      "Log in using the account your school has provided you with. A student's login will typically end with an 'u' letter.";

  @override
  Uri? get providerBannerUri => Uri.parse('https://api.librus.pl/OAuth/images/synergia-logo.png');

  @override
  Map<String, ({String name, bool obscure, ({String text, Uri link})? helper})> get credentialsConfig => kIsWeb
      ? {
          'login': (name: 'Username', obscure: false, helper: null),
          'pass': (name: 'Password', obscure: true, helper: null),
          'proxy': (
            name: 'Proxy URL',
            obscure: false,
            helper: (text: 'Create your own proxy using our template', link: Uri.parse('https://github.com/Ogaku/Oshi/wiki/Web-app'))
          )
        }
      : {'login': (name: 'Username', obscure: false, helper: null), 'pass': (name: 'Password', obscure: true, helper: null)};

  @override
  Future<({Exception? message, Message? result, bool success})> fetchMessageContent(
      {required Message parent, required bool byMe}) async {
    try {
      // Cache other data to access it faster (the API is shit and splits everything)
      var teachersShim = Users.fromJson(await data!.librusApi!.request("Users"));
      var result = parent; // Cache the message for overwriting

      try {
        var messagesUsers =
            MessagesUsers.fromJson(await data!.librusApi!.messagesRequest("receivers/groups/school-employees"));

        teachersShim.users
            ?.where((user) => messagesUsers.receivers?.any((receiver) => receiver.userIdInt == user.id) ?? false)
            .forEach((user) {
          user.userId =
              messagesUsers.receivers!.firstWhereOrDefault((receiver) => receiver.userIdInt == user.id)?.accountIdInt;
        });
      } catch (ex) {
        // ignored
      }

      if (!byMe) {
        // Get the actual underlying message
        var message = InboxMessage.fromJson(await data!.librusApi!.messagesRequest('inbox/messages/${parent.id}'));
        var content = (message.data?.message ?? '')
            .tryBase64Decoded()
            .replaceAll('<Message><Content><![CDATA[', '')
            .replaceAll(']]></Content><Actions><Actions/></Actions></Message>', '')
            .trim();

        await Future.forEach(RegExp('(?<=systemu.">)(.*?)(?=</a>)').allMatches(content), (x) async {
          var link = x.group(0) ?? '';

          try {
            if (link.isNotEmpty && link.startsWith('https://liblink.pl/'))
              link = (await Dio(BaseOptions(
                      followRedirects: false,
                      validateStatus: (status) {
                        return status != null && status < 500;
                      })).post(link))
                  .headers['location']!
                  .first;
          } catch (ex) {
            // ignored
          }

          content = content.replaceFirst(RegExp('<a href="(.*?)</a>'), link);
        });

        result = Message(
            id: parent.id,
            url: parent.url,
            topic: message.data?.topic ?? 'No topic',
            sendDate: message.data?.sendDate ?? DateTime.now(),
            readDate: message.data?.readDate,
            content: content,
            sender: teachersShim.users!
                    .firstWhereOrDefault((user) => user.userId == int.tryParse(message.data?.senderId ?? ''),
                        defaultValue: null)
                    ?.asTeacher() ??
                models.Teacher(
                    firstName: message.data?.senderFirstName ?? 'Unknown',
                    lastName: message.data?.senderLastName ?? 'sender'),
            hasAttachments: message.data?.attachments?.isNotEmpty ?? false,
            attachments: (await message.data?.attachments?.select((y, index) async {
              var url = (await data!.librusApi!.messagesRequest('attachments/${y.id}/messages/${parent.id}'))['data']
                      ?['downloadLink']
                  ?.toString();
              return models.Attachment(name: y.filename, location: (url?.contains('GetFile') ?? false) ? '$url/get' : url);
            }).awaitAll())
                ?.toList());
      } else {
        // Get the actual underlying message
        var message = OutboxMessage.fromJson(await data!.librusApi!.messagesRequest('outbox/messages/${parent.id}'));
        var content = (message.data?.message ?? '')
            .tryBase64Decoded()
            .replaceAll('<Message><Content><![CDATA[', '')
            .replaceAll(']]></Content><Actions><Actions/></Actions></Message>', '')
            .trim();

        await Future.forEach(RegExp('(?<=systemu.">)(.*?)(?=</a>)').allMatches(content), (x) async {
          var link = x.group(0) ?? '';

          try {
            if (link.isNotEmpty && link.startsWith('https://liblink.pl/'))
              link = (await Dio(BaseOptions(
                      followRedirects: false,
                      validateStatus: (status) {
                        return status != null && status < 500;
                      })).post(link))
                  .headers['location']!
                  .first;
          } catch (ex) {
            // ignored
          }

          content = content.replaceFirst(RegExp('<a href="(.*?)</a>'), link);
        });

        result = Message(
            id: parent.id,
            url: parent.url,
            topic: message.data?.topic ?? 'No topic',
            sendDate: message.data?.sendDate ?? DateTime.now(),
            readDate: message.data?.readDate,
            content: content,
            receivers: message.data?.receivers
                ?.select((y, index) =>
                    teachersShim.users!
                        .firstWhereOrDefault((user) => user.userId == int.tryParse(y.receiverId))
                        ?.asTeacher() ??
                    const models.Teacher())
                .toList());
      }

      return (success: true, message: null, result: result);
    } on Exception catch (ex) {
      return (success: false, message: ex, result: null);
    } catch (ex) {
      return (success: false, message: Exception(ex), result: null);
    }
  }

  @override
  Future<({Exception? message, bool success})> moveMessageToTrash({required Message parent, required bool byMe}) async {
    try {
      await data!.librusApi!.messagesDelete('messages/${parent.id}');
      return (success: true, message: null);
    } on Exception catch (ex) {
      return (success: false, message: ex);
    } catch (ex) {
      return (success: false, message: Exception(ex));
    }
  }

  @override
  Future<({Exception? message, bool success})> markEventAsViewed({required models.Event parent}) async {
    try {
      await data!.librusApi!.request('HomeWorkAssignments/${parent.id}');
      return (success: true, message: null);
    } on Exception catch (ex) {
      return (success: false, message: ex);
    } catch (ex) {
      return (success: false, message: Exception(ex));
    }
  }

  @override
  Future<({Exception? message, bool success})> markEventAsDone({required models.Event parent}) async {
    try {
      await data!.librusApi!.post('HomeWorkAssignments/MarkAsDone', {'homework': parent.id});
      return (success: true, message: null);
    } on Exception catch (ex) {
      return (success: false, message: ex);
    } catch (ex) {
      return (success: false, message: Exception(ex));
    }
  }

  @override
  Future<({Exception? message, bool success})> markAnnouncementAsViewed({required models.Announcement parent}) async {
    try {
      await data!.librusApi!.post('SchoolNotices/MarkAsRead/${parent.url}', {});
      return (success: true, message: null);
    } on Exception catch (ex) {
      return (success: false, message: ex);
    } catch (ex) {
      return (success: false, message: Exception(ex));
    }
  }
}

extension FirstLettersNames on String {
  String get firstLettersName => split(' ').where((x) => x.isNotEmpty).select((x, _) => x[0].toLowerCase()).join();
}

extension ClassTeamCodeExtension on models.Class {
  String get teamCode => '${unit.id}${unit.fullName.firstLettersName}_${unit.town}:${(name ?? symbol)}'.toLowerCase();
  MapEntry<String, String> get teamCodePair => MapEntry(teamCode, (name ?? symbol));
}

extension DecodingExtension on String {
  String tryBase64Decoded() {
    try {
      return utf8.decode(base64.decode(this));
    } catch (ex, stack) {
      if (isAndroid) {
        Logger('Temporary: tryBase64Decoded')
          ..severe(ex) // The exception
          ..severe(stack); // The stack
      }
      return '';
    }
  }
}

extension UserExtension on User {
  models.Teacher asTeacher() => models.Teacher(
      id: id, userId: userId, url: '', firstName: firstName, lastName: lastName, isHomeTeacher: isHomeTeacher, absent: null);
}

extension SubjectExtension on Subject {
  models.Lesson asSubject() => models.Lesson(
      id: id, url: '', name: name, no: no, short: short, isExtracurricular: isExtracurricular, isBlockLesson: isBlockLesson);
}

extension ClassroomExtension on Classroom {
  models.Classroom asClassroom() => models.Classroom(id: id, name: name, symbol: symbol, url: '');
}

extension ClassExtension on StudentClass {
  models.Class asClass(models.Unit unit, models.Teacher teacher) => models.Class(
        id: studentClassClass!.id,
        number: studentClassClass!.number,
        symbol: studentClassClass!.symbol,
        name: studentClassClass!.number.toString() + studentClassClass!.symbol,
        beginSchoolYear: studentClassClass!.beginSchoolYear ?? DateTime.now(),
        endFirstSemester: studentClassClass!.endFirstSemester ?? DateTime.now(),
        endSchoolYear: studentClassClass!.endSchoolYear ?? DateTime.now(),
        unit: unit,
        classTutor: teacher,
        events: List.empty(),
      );
}

extension UnitExtensions on StudentUnit {
  models.Unit asUnit(School school) => models.Unit(
        id: school.id,
        url: '',
        luckyNumber: null,
        name: unit!.name,
        fullName: school.name,
        principalName: '${school.nameHeadTeacher} ${school.surnameHeadTeacher}',
        address: "${school.buildingNumber} ${school.street.replaceAll('ul. ', '')}, ${school.town}",
        town: school.town,
        email: school.email,
        phone: school.phoneNumber,
        type: unit!.type,
        behaviourType: unit!.behaviourType,
        lessonsRange: unit!.lessonsRange!
            .select((element, index) => models.LessonRanges(from: element.fromTime, to: element.toTime))
            .toList(),
        announcements: null,
        teacherAbsences: null,
      );
}

extension VirtualClassExtension on VirtualClass {
  models.Class asClass(models.Class homeClass) => models.Class(
        id: id,
        number: number,
        symbol: symbol,
        name: name,
        beginSchoolYear: homeClass.beginSchoolYear,
        endFirstSemester: homeClass.endFirstSemester,
        endSchoolYear: homeClass.endSchoolYear,
        unit: homeClass.unit,
        classTutor: homeClass.classTutor,
        events: List.empty(),
      );
}

extension DateOnlyCompare on DateTime {
  bool isSameDate(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }
}

extension AttendanceExtension on int {
  models.AttendanceType asAttendance() {
    return switch (this) {
      1 => models.AttendanceType.absent, // Nieobencosc
      2 => models.AttendanceType.late, // Spoznienie
      3 => models.AttendanceType.excused, // Usprawiedliwione
      4 => models.AttendanceType.duty, // Zwolnienie/wycieczka
      100 => models.AttendanceType.present, // Obecnosc
      _ => models.AttendanceType.absent, // Nieobencosc
    };
  }
}

extension CategoryExtension on Category {
  models.EventCategory asEvent() {
    return switch (id) {
      10839 => models.EventCategory.gathering, // Zebranie rodzicielskie
      10840 => models.EventCategory.lecture, // Lektura
      11093 => models.EventCategory.test, // Test
      11094 => models.EventCategory.classWork, // Praca klasowa
      11715 => models.EventCategory.semCorrection, // Poprawa półrocza
      11716 => models.EventCategory.other, // Inne
      11717 => models.EventCategory.lessonWork, // Praca na lekcji
      11853 => models.EventCategory.shortTest, // Kartkówka
      15753 => models.EventCategory.correction, // Poprawa
      17337 => models.EventCategory.onlineLesson, // Spotkanie / lekcja online
      _ => models.EventCategory.other // Inne
    };
  }
}

List<T> addOrReplace<T>(List<T>? oldList, List<T> newList) {
  if (oldList != null) {
    oldList.addAll(newList);
    return oldList;
  } else
    return newList;
}

List<T> addOrReplaceItem<T>(List<T>? oldList, T newItem) {
  if (oldList != null) {
    oldList.add(newItem);
    return oldList;
  } else
    return [newItem];
}
