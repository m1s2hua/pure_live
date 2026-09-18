import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

typedef CustomSourceApplier = Future<bool> Function(String url);

/// Pasting a self-captured stream URL replaces only the media source of the
/// current room. The dialog owns validation feedback and close-on-success; the
/// controller owns the fenced playback transaction.
class CustomSourceDialog {
  const CustomSourceDialog._();

  static Future<void> show({
    required BuildContext context,
    required LivePlayController controller,
    @visibleForTesting CustomSourceApplier? applySource,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CustomSourceEditor(applySource: applySource ?? controller.playCustomSource),
    );
  }
}

class _CustomSourceEditor extends StatefulWidget {
  const _CustomSourceEditor({required this.applySource});

  final CustomSourceApplier applySource;

  @override
  State<_CustomSourceEditor> createState() => _CustomSourceEditorState();
}

class _CustomSourceEditorState extends State<_CustomSourceEditor> {
  final TextEditingController _urlController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final url = _urlController.text.trim();
    if (!isValidCustomSourceUrl(url)) {
      setState(() {
        _error = i18n('custom_play_source_invalid_url');
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    bool applied;
    try {
      applied = await widget.applySource(url);
    } catch (_) {
      applied = false;
    }
    if (!mounted) return;
    if (applied) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = i18n('custom_play_source_failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: height > 40 ? height - 40 : height),
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(i18n('custom_play_source'), style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          i18n('custom_play_source_desc'),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('custom-source-url-field'),
                          controller: _urlController,
                          autofocus: true,
                          enabled: !_saving,
                          maxLines: 2,
                          minLines: 1,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: i18n('custom_play_source_url'),
                            hintText: 'https://example.com/live/stream.flv',
                          ),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              key: const ValueKey('custom-source-error'),
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: Text(i18n('cancel')),
                          ),
                          FilledButton(
                            key: const ValueKey('custom-source-confirm'),
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(i18n('confirm')),
                                    ],
                                  )
                                : Text(i18n('confirm')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
