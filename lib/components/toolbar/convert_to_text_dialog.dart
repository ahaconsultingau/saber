import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/i18n/strings.g.dart';

/// What to do with the converted text.
typedef ConvertToTextResult = ({String text, bool removeHandwriting});

/// Reads the selected handwriting and shows the text to check and edit.
///
/// Pops with the (possibly edited) text and whether to remove the
/// handwriting, or null if cancelled or there's nothing to add.
class ConvertToTextDialog extends StatefulWidget {
  const new({
    super.key,
    required this.isModelDownloaded,
    required this.downloadModel,
    required this.recognize,
  });

  final Future<bool> Function() isModelDownloaded;
  final Future<bool> Function() downloadModel;
  final Future<String> Function() recognize;

  @override
  State<ConvertToTextDialog> createState() => _ConvertToTextDialogState();
}

enum _Stage { downloading, reading, result, nothingFound, failed }

class _ConvertToTextDialogState extends State<ConvertToTextDialog> {
  var stage = _Stage.reading;
  final text = TextEditingController();
  var removeHandwriting = false;
  var copied = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    try {
      if (!await widget.isModelDownloaded()) {
        _setStage(.downloading);
        if (!await widget.downloadModel()) return _setStage(.failed);
      }
      _setStage(.reading);
      final result = await widget.recognize();
      text.text = result;
      _setStage(result.trim().isEmpty ? .nothingFound : .result);
    } catch (_) {
      _setStage(.failed);
    }
  }

  void _setStage(_Stage value) {
    if (mounted) setState(() => stage = value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.editor.convertToText;
    return AdaptiveAlertDialog(
      title: Text(strings.title),
      content: SizedBox(
        width: 480,
        child: switch (stage) {
          .downloading => _Progress(strings.downloading),
          .reading => _Progress(strings.reading),
          .nothingFound => Text(strings.nothingFound),
          .failed => Text(strings.failed),
          .result => Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              TextField(
                key: const ValueKey('convertedText'),
                controller: text,
                minLines: 2,
                maxLines: 10,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              CheckboxListTile(
                contentPadding: .zero,
                controlAffinity: .leading,
                value: removeHandwriting,
                onChanged: (value) =>
                    setState(() => removeHandwriting = value ?? false),
                title: Text(strings.removeHandwriting),
              ),
              Text(
                strings.textLayerNote,
                style: TextTheme.of(context).bodySmall,
              ),
            ],
          ),
        },
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        if (stage == .result) ...[
          CupertinoDialogAction(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text.text));
              if (mounted) setState(() => copied = true);
            },
            child: Text(copied ? strings.copied : strings.copy),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop<ConvertToTextResult>((
              text: text.text.trim(),
              removeHandwriting: removeHandwriting,
            )),
            child: Text(strings.addToPage),
          ),
        ],
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const new(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(message)),
      ],
    );
  }
}
