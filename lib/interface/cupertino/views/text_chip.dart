import 'package:flutter/cupertino.dart';

class TextChip extends StatefulWidget {
  final String text;
  final EdgeInsets? insets;
  final EdgeInsets? margin;
  final void Function()? tapped;

  const TextChip({super.key, required this.text, this.tapped, this.insets, this.margin});

  @override
  State<TextChip> createState() => _NavState();
}

class _NavState extends State<TextChip> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.insets ?? const EdgeInsets.only(left: 8, top: 5, right: 8, bottom: 5),
      margin: widget.margin ?? const EdgeInsets.all(0),
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10)), color: Color(0x33AAAAAA)),
      child: Text(
        widget.text,
        style: const TextStyle(color: CupertinoColors.systemBlue, fontSize: 16),
      ),
    );
  }
}
