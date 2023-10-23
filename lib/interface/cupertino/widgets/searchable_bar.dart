import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:oshi/interface/cupertino/widgets/navigation_bar.dart';

class SearchableSliverNavigationBar extends StatefulWidget {
  final Widget? largeTitle;
  final Widget? leading;
  final bool? alwaysShowMiddle;
  final String? previousPageTitle;
  final Widget? middle;
  final Widget? trailing;
  final Color color;
  final Color darkColor;
  final bool? transitionBetweenRoutes;
  final TextEditingController searchController;
  final List<Widget>? children;
  final Widget? child;
  final Map<String, String>? segments;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;

  const SearchableSliverNavigationBar(
      {super.key,
      required this.searchController,
      this.children,
      this.onChanged,
      this.onSubmitted,
      this.transitionBetweenRoutes,
      this.largeTitle,
      this.leading,
      this.alwaysShowMiddle = false,
      this.previousPageTitle,
      this.middle,
      this.trailing,
      this.child,
      this.segments,
      this.color = Colors.white,
      this.darkColor = Colors.black});

  @override
  // ignore: no_logic_in_create_state
  State<SearchableSliverNavigationBar> createState() => _NavState();
}

class _NavState extends State<SearchableSliverNavigationBar> {
  late ScrollController scrollController;
  late String? groupSelection;
  double previousScrollPosition = 0, isVisibleSearchBar = 0;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController(initialScrollOffset: widget.child == null ? 40 : 0);
    groupSelection = widget.segments?.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    var navBarSliver = SliverNavigationBar(
      alternativeVisibility: widget.child != null,
      transitionBetweenRoutes: widget.transitionBetweenRoutes,
      leading: widget.leading,
      previousPageTitle: widget.previousPageTitle,
      threshold: 97,
      middle: widget.middle ?? widget.largeTitle,
      largeTitle: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: widget.largeTitle),
          Visibility(
              visible: widget.child == null,
              child: Container(
                margin: const EdgeInsets.only(top: 5),
                height: lerpDouble(0, 42, isVisibleSearchBar.clamp(0.0, 40.0) / 40.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 0, right: 15, top: 3),
                  child: widget.segments != null
                      ? CupertinoSlidingSegmentedControl(
                          groupValue: groupSelection,
                          children: widget.segments!.map((key, value) => MapEntry(
                              key,
                              Container(
                                  width: double.maxFinite,
                                  child: Text(value,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: lerpDouble(13, 15, ((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0)),
                                          color: CupertinoDynamicColor.resolve(
                                              CupertinoDynamicColor.withBrightness(
                                                  color: CupertinoColors.black.withAlpha(
                                                      (((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0) * 153).round()),
                                                  darkColor: CupertinoColors.white.withAlpha(
                                                      (((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0) * 153).round())),
                                              context)))))),
                          onValueChanged: (value) {
                            if (value == null) return;
                            setState(() => groupSelection = value);
                            if (widget.onChanged != null) widget.onChanged!(value);
                          },
                        )
                      : CupertinoSearchTextField(
                          onChanged: widget.onChanged,
                          placeholderStyle: TextStyle(
                              fontSize: lerpDouble(13, 17, ((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0)),
                              color: CupertinoDynamicColor.withBrightness(
                                  color: const Color.fromARGB(153, 60, 60, 67)
                                      .withAlpha((((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0) * 153).round()),
                                  darkColor: const Color.fromARGB(153, 235, 235, 245)
                                      .withAlpha((((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0) * 153).round()))),
                          prefixIcon: AnimatedOpacity(
                            duration: const Duration(milliseconds: 1),
                            opacity: ((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0),
                            child: Transform.scale(
                                scale: lerpDouble(0.7, 1.1, ((isVisibleSearchBar - 30) / 10).clamp(0.0, 1.0)),
                                child: Container(
                                    margin: const EdgeInsets.only(top: 2, left: 2),
                                    child: const Icon(CupertinoIcons.search))),
                          ),
                          controller: widget.searchController,
                          onSubmitted: widget.onSubmitted,
                        ),
                ),
              )),
        ],
      ),
      scrollController: scrollController,
      alwaysShowMiddle: false,
      trailing: widget.trailing,
    );

    return CupertinoPageScaffold(
        backgroundColor: const CupertinoDynamicColor.withBrightness(
            color: Color.fromARGB(255, 242, 242, 247), darkColor: Color.fromARGB(255, 0, 0, 0)),
        child: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification scrollInfo) {
            if (widget.child != null) return true;
            if (scrollInfo is ScrollUpdateNotification) {
              if (scrollInfo.metrics.pixels > previousScrollPosition) {
                if (isVisibleSearchBar > 0 && scrollInfo.metrics.pixels > 0) {
                  setState(() {
                    isVisibleSearchBar = (40 - scrollInfo.metrics.pixels) >= 0 ? (40 - scrollInfo.metrics.pixels) : 0;
                  });
                }
              } else if (scrollInfo.metrics.pixels <= previousScrollPosition) {
                if (isVisibleSearchBar < 40 && scrollInfo.metrics.pixels >= 0 && scrollInfo.metrics.pixels <= 40) {
                  setState(() {
                    isVisibleSearchBar = (40 - scrollInfo.metrics.pixels) <= 40 ? (40 - scrollInfo.metrics.pixels) : 40;
                  });
                }
              }
              setState(() {
                previousScrollPosition = scrollInfo.metrics.pixels;
              });
            } else if (scrollInfo is ScrollEndNotification) {
              Future.delayed(Duration.zero, () {
                if (isVisibleSearchBar < 30 && isVisibleSearchBar > 0) {
                  setState(() {
                    scrollController.animateTo(40, duration: const Duration(milliseconds: 200), curve: Curves.ease);
                  });
                } else if (isVisibleSearchBar >= 30 && isVisibleSearchBar <= 40) {
                  setState(() {
                    scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.ease);
                  });
                }
              });
            }
            return true;
          },
          child: widget.child != null
              ? NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [navBarSliver],
                  body: widget.child!,
                  controller: scrollController)
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: scrollController,
                  anchor: 0.055,
                  slivers: <Widget>[
                    navBarSliver,
                    SliverFillRemaining(
                        hasScrollBody: false,
                        child: widget.child ??
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: widget.children ?? [],
                            )),
                  ],
                ),
        ));
  }
}
