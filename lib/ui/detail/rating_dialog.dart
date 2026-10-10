import 'package:flutter/material.dart';

/// Asks for a 1–10 rating.
///
/// Returns the rating, `0` to clear it, or `null` when cancelled.
Future<int?> showRatingDialog(BuildContext context, {int? current}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _RatingDialog(current: current),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({this.current});

  final int? current;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late int _value = widget.current ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your rating'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _value == 0 ? 'Not rated' : '$_value / 10',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Slider(
            value: _value.toDouble(),
            max: 10,
            divisions: 10,
            label: '$_value',
            onChanged: (value) => setState(() => _value = value.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(0),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _value == 0
              ? null
              : () => Navigator.of(context).pop(_value),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
