import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<DateTime?> showPlatformDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  if (!Platform.isIOS) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    );
  }
  DateTime selected = initialDate;
  bool confirmed = false;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _PickerSheet(
      height: 300,
      onDone: () {
        confirmed = true;
        Navigator.pop(ctx);
      },
      onCancel: () => Navigator.pop(ctx),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initialDate,
        minimumDate: firstDate ?? DateTime(2020),
        maximumDate: lastDate ?? DateTime(2035),
        onDateTimeChanged: (dt) => selected = dt,
      ),
    ),
  );
  return confirmed ? selected : null;
}

Future<TimeOfDay?> showPlatformTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  if (!Platform.isIOS) {
    return showTimePicker(context: context, initialTime: initialTime);
  }
  final initialDt = DateTime(2000, 1, 1, initialTime.hour, initialTime.minute);
  DateTime selected = initialDt;
  bool confirmed = false;
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _PickerSheet(
      height: 260,
      onDone: () {
        confirmed = true;
        Navigator.pop(ctx);
      },
      onCancel: () => Navigator.pop(ctx),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: initialDt,
        use24hFormat: false,
        onDateTimeChanged: (dt) => selected = dt,
      ),
    ),
  );
  return confirmed
      ? TimeOfDay(hour: selected.hour, minute: selected.minute)
      : null;
}

class _PickerSheet extends StatelessWidget {
  final Widget child;
  final double height;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const _PickerSheet({
    required this.child,
    required this.height,
    required this.onDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
