// ignore_for_file: prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'dart:io';

import 'package:darq/darq.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:oshi/interface/cupertino/views/message_compose.dart';
import 'package:oshi/interface/cupertino/views/message_detailed.dart';
import 'package:oshi/interface/cupertino/widgets/searchable_bar.dart';
import 'package:oshi/models/data/messages.dart';
import 'package:oshi/models/data/teacher.dart';
import 'package:oshi/share/share.dart';
import 'package:pull_down_button/pull_down_button.dart';
import 'package:share_plus/share_plus.dart' as sharing;
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

// Boiler: returned to the app tab builder
StatefulWidget get messagesPage => MessagesPage();

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final searchController = TextEditingController();

  String searchQuery = '';
  String? _progressMessage;

  MessageFolders folder = MessageFolders.inbox;
  bool isWorking = false;

  @override
  Widget build(BuildContext context) {
    var messagesToDisplay = (switch (folder) {
      MessageFolders.inbox => Share.session.data.messages.received,
      MessageFolders.outbox => Share.session.data.messages.sent,
      _ => <Message>[]
    })
        .where((x) =>
            x.topic.contains(RegExp(searchQuery, caseSensitive: false)) ||
            x.sendDateString.contains(RegExp(searchQuery, caseSensitive: false)) ||
            x.previewString.contains(RegExp(searchQuery, caseSensitive: false)) ||
            (x.content?.contains(RegExp(searchQuery, caseSensitive: false)) ?? false) ||
            x.senderName.contains(RegExp(searchQuery, caseSensitive: false)))
        .toList();

    if (folder == MessageFolders.announcements) {
      messagesToDisplay = Share.session.data.student.mainClass.unit.announcements
              ?.where((x) =>
                  x.subject.contains(RegExp(searchQuery, caseSensitive: false)) ||
                  x.content.contains(RegExp(searchQuery, caseSensitive: false)) ||
                  (x.contact?.name.contains(RegExp(searchQuery, caseSensitive: false)) ?? false))
              .orderByDescending((x) => x.startDate)
              .select((x, index) => Message(
                  topic: x.subject,
                  content: x.content,
                  sender: x.contact ?? Teacher(firstName: Share.session.data.student.mainClass.unit.name),
                  sendDate: x.startDate,
                  readDate: x.endDate))
              .toList() ??
          [];
    }

    var messagesWidget = CupertinoListSection.insetGrouped(
      margin: EdgeInsets.only(left: 15, right: 15, bottom: 10),
      additionalDividerMargin: 5,
      children: messagesToDisplay.isEmpty
          // No messages to display
          ? [
              CupertinoListTile(
                  title: Opacity(
                      opacity: 0.5,
                      child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            folder == MessageFolders.announcements
                                ? (searchQuery.isEmpty ? 'No announcements, yet...' : 'No announcements matching the query')
                                : (searchQuery.isEmpty ? 'No messages, yet...' : 'No messages matching the query'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                          ))))
            ]
          // Bindable messages layout
          : messagesToDisplay
              .select((x, index) => SwipeActionCell(
                  key: UniqueKey(),
                  backgroundColor: Colors.transparent,
                  trailingActions: <SwipeAction>[
                    SwipeAction(
                        performsFirstActionWithFullSwipe: true,
                        content: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: CupertinoColors.destructiveRed,
                          ),
                          child: Icon(
                            CupertinoIcons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onTap: (CompletionHandler handler) async {
                          await handler(true);
                          try {
                            setState(() {
                              (folder == MessageFolders.outbox
                                      ? Share.session.data.messages.sent
                                      : Share.session.data.messages.received)
                                  .remove(x);
                              isWorking = true;
                            });
                            Share.session.provider
                                .moveMessageToTrash(parent: x, byMe: folder == MessageFolders.outbox)
                                .then((value) => setState(() => isWorking = false));
                          } on Exception catch (e) {
                            setState(() => isWorking = false);
                            if (Platform.isAndroid || Platform.isIOS) {
                              Fluttertoast.showToast(
                                msg: '$e',
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.CENTER,
                                timeInSecForIosWeb: 1,
                              );
                            }
                          }
                        },
                        color: CupertinoColors.destructiveRed),
                    SwipeAction(
                        content: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: CupertinoColors.systemBlue,
                          ),
                          child: Icon(
                            CupertinoIcons.share,
                            color: Colors.white,
                          ),
                        ),
                        onTap: (CompletionHandler handler) => sharing.Share.share(folder == MessageFolders.outbox
                            ? 'On ${DateFormat("EEE, MMM d, y 'a't hh:mm a").format(x.sendDate)} ${Share.session.data.student.account.name}, ${Share.session.data.student.mainClass.name} wrote:\n"${x.topic}\n\n${x.preview}[...]"'
                            : 'On ${DateFormat("EEE, MMM d, y 'a't hh:mm a").format(x.sendDate)} ${x.sender?.name} wrote:\n"${x.topic}\n\n${x.preview}[...]"'),
                        color: CupertinoColors.systemBlue),
                  ],
                  child: CupertinoListTile(
                      padding: EdgeInsets.all(0),
                      title: CupertinoContextMenu.builder(
                          enableHapticFeedback: true,
                          actions: [
                            CupertinoContextMenuAction(
                              onPressed: () {
                                sharing.Share.share(folder == MessageFolders.outbox
                                    ? 'On ${DateFormat("EEE, MMM d, y 'a't hh:mm a").format(x.sendDate)} ${Share.session.data.student.account.name}, ${Share.session.data.student.mainClass.name} wrote:\n"${x.topic}\n\n${x.preview}[...]"'
                                    : 'On ${DateFormat("EEE, MMM d, y 'a't hh:mm a").format(x.sendDate)} ${x.sender?.name} wrote:\n"${x.topic}\n\n${x.preview}[...]"');
                                Navigator.of(context, rootNavigator: true).pop();
                              },
                              trailingIcon: CupertinoIcons.share,
                              child: const Text('Share'),
                            ),
                            CupertinoContextMenuAction(
                              isDestructiveAction: true,
                              trailingIcon: CupertinoIcons.trash,
                              child: const Text('Delete'),
                              onPressed: () {
                                if (isWorking) return;
                                try {
                                  setState(() {
                                    (folder == MessageFolders.outbox
                                            ? Share.session.data.messages.sent
                                            : Share.session.data.messages.received)
                                        .remove(x);
                                    isWorking = true;
                                  });
                                  Share.session.provider
                                      .moveMessageToTrash(parent: x, byMe: folder == MessageFolders.outbox)
                                      .then((value) => setState(() => isWorking = false));
                                } on Exception catch (e) {
                                  setState(() => isWorking = false);
                                  if (Platform.isAndroid || Platform.isIOS) {
                                    Fluttertoast.showToast(
                                      msg: '$e',
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.CENTER,
                                      timeInSecForIosWeb: 1,
                                    );
                                  }
                                }
                                // Close the current page
                                Navigator.of(context, rootNavigator: true).pop();
                              },
                            ),
                          ],
                          builder: (BuildContext swipeContext, Animation<double> animation) => GestureDetector(
                              onTap: () {
                                if (isWorking) return;
                                try {
                                  if (folder == MessageFolders.announcements) {
                                    Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                            builder: (context) => MessageDetailsPage(
                                                  message: x,
                                                  isByMe: false,
                                                )));
                                  } else {
                                    setState(() => isWorking = true);

                                    Share.session.provider
                                        .fetchMessageContent(parent: x, byMe: folder == MessageFolders.outbox)
                                        .then((result) {
                                      setState(() => isWorking = false);

                                      if (result.message == null && result.result != null && folder == MessageFolders.inbox) {
                                        var index = Share.session.data.messages.received.indexOf(x);
                                        Share.session.data.messages.received[index] = Message.from(other: result.result!);
                                        x = Share.session.data.messages.received[index]; // Update x too
                                      }
                                      if (result.message == null && result.result != null && folder == MessageFolders.outbox) {
                                        var index = Share.session.data.messages.sent.indexOf(x);
                                        Share.session.data.messages.sent[index] = Message.from(other: result.result!);
                                        x = Share.session.data.messages.sent[index]; // Update x too
                                      }

                                      if (x.content?.isEmpty ?? true) return;
                                      if (folder == MessageFolders.inbox) {
                                        Share.session.data.messages
                                                .received[Share.session.data.messages.received.indexOf(x)] =
                                            Message.from(other: x, readDate: DateTime.now());
                                      }

                                      Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                              builder: (context) => MessageDetailsPage(
                                                    message: x,
                                                    isByMe: folder == MessageFolders.outbox,
                                                  )));
                                    });
                                  }
                                } on Exception catch (e) {
                                  setState(() => isWorking = false);
                                  if (Platform.isAndroid || Platform.isIOS) {
                                    Fluttertoast.showToast(
                                      msg: '$e',
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.CENTER,
                                      timeInSecForIosWeb: 1,
                                    );
                                  }
                                }
                              },
                              child: Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                      color: CupertinoDynamicColor.resolve(
                                          CupertinoDynamicColor.withBrightness(
                                              color: const Color.fromARGB(255, 255, 255, 255),
                                              darkColor: const Color.fromARGB(255, 28, 28, 30)),
                                          context)),
                                  padding: EdgeInsets.only(top: 15, bottom: 15, right: 15, left: 20),
                                  child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight: animation.value < CupertinoContextMenu.animationOpensAt
                                              ? double.infinity
                                              : 100,
                                          maxWidth: animation.value < CupertinoContextMenu.animationOpensAt
                                              ? double.infinity
                                              : 250),
                                      child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Visibility(
                                                      visible: !x.read && folder == MessageFolders.inbox,
                                                      child: Container(
                                                          margin: EdgeInsets.only(top: 5, right: 6),
                                                          child: Container(
                                                            height: 10,
                                                            width: 10,
                                                            decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                color: CupertinoTheme.of(context).primaryColor),
                                                          ))),
                                                  Expanded(
                                                      child: Container(
                                                          margin: EdgeInsets.only(right: 10),
                                                          child: Text(
                                                            x.senderName,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                                          ))),
                                                  Visibility(
                                                    visible: x.hasAttachments,
                                                    child: Transform.scale(
                                                        scale: 0.6,
                                                        child: Icon(CupertinoIcons.paperclip,
                                                            color: CupertinoColors.inactiveGray)),
                                                  ),
                                                  Container(
                                                      margin: EdgeInsets.only(top: 1),
                                                      child: Opacity(
                                                          opacity: 0.5,
                                                          child: Text(
                                                            folder == MessageFolders.announcements
                                                                ? (x.sendDate.month == x.readDate?.month &&
                                                                        x.sendDate.year == x.readDate?.year &&
                                                                        x.sendDate.day != x.readDate?.day
                                                                    ? '${DateFormat('MMM d').format(x.sendDate)} - ${DateFormat('d').format(x.readDate ?? DateTime.now())}'
                                                                    : '${DateFormat('MMM d').format(x.sendDate)} - ${DateFormat(x.sendDate.year == x.readDate?.year ? 'MMM d' : 'MMM d y').format(x.readDate ?? DateTime.now())}')
                                                                : x.sendDateString,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                                                          )))
                                                ]),
                                            Container(
                                                margin: EdgeInsets.only(top: 3),
                                                child: Text(
                                                  x.topic,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 16),
                                                )),
                                            Opacity(
                                                opacity: 0.5,
                                                child: Container(
                                                    margin: EdgeInsets.only(top: 5),
                                                    child: Text(
                                                      x.previewString.replaceAll('\n ', '\n').replaceAll('\n\n', '\n'),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(fontSize: 16),
                                                    ))),
                                          ]))))))))
              .toList(),
    );

    return SearchableSliverNavigationBar(
      setState: setState,
      useSliverBox: true,
      largeTitle: Text('Messages'),
      middle: Visibility(visible: _progressMessage?.isEmpty ?? true, child: Text('Messages')),
      onProgress: (progress) => setState(() => _progressMessage = progress?.message),
      leading: Visibility(
          visible: _progressMessage?.isNotEmpty ?? false,
          child: Container(
              margin: EdgeInsets.only(top: 7),
              child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 150),
                  child: Text(
                    _progressMessage ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: CupertinoColors.inactiveGray, fontSize: 13),
                  )))),
      searchController: searchController,
      onChanged: (s) => setState(() => searchQuery = s),
      trailing: isWorking
          ? Container(margin: EdgeInsets.only(right: 5, top: 5), child: CupertinoActivityIndicator(radius: 12))
          : PullDownButton(
              itemBuilder: (context) => [
                PullDownMenuItem(
                  title: 'New',
                  icon: CupertinoIcons.add,
                  onTap: () {
                    showCupertinoModalBottomSheet(
                        context: context,
                        builder: (context) => MessageComposePage(
                            signature:
                                '${Share.session.data.student.account.name}, ${Share.session.data.student.mainClass.name}'));
                  },
                ),
                PullDownMenuDivider.large(),
                PullDownMenuTitle(title: Text('Folders')),
                PullDownMenuItem(
                  title: 'Received',
                  icon: folder == MessageFolders.inbox ? CupertinoIcons.tray_fill : CupertinoIcons.tray,
                  onTap: () => setState(() => folder = MessageFolders.inbox),
                ),
                PullDownMenuItem(
                  title: 'Sent',
                  icon: folder == MessageFolders.outbox ? CupertinoIcons.paperplane_fill : CupertinoIcons.paperplane,
                  onTap: () => setState(() => folder = MessageFolders.outbox),
                ),
                PullDownMenuItem(
                  title: 'Announcements',
                  icon: folder == MessageFolders.announcements ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
                  onTap: () => setState(() => folder = MessageFolders.announcements),
                )
              ],
              buttonBuilder: (context, showMenu) => GestureDetector(
                onTap: showMenu,
                child: const Icon(CupertinoIcons.ellipsis_circle),
              ),
            ),
      children: [messagesWidget],
    );
  }
}

enum MessageFolders { inbox, outbox, announcements }
