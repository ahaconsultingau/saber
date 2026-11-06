import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_circular_progress_indicator.dart';
import 'package:saber/data/is_this_a_test.dart';
import 'package:saber/data/routes.dart';

/// Replaces the back button as the
/// [AppBar.leading] widget in the [AppBar]
/// to indicate the state of saving in the editor.
class SaveIndicator extends StatelessWidget {
  const new({super.key, required this.savingState, required this.triggerSave});

  final ValueNotifier<SavingState> savingState;
  final Future<void> Function() triggerSave;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: savingState,
      builder: (context, isSaving, _) {
        return AnimatedSwitcher(
          duration: isThisATest
              ? Duration.zero
              : const Duration(milliseconds: 300),
          child: IconButton(
            key: ValueKey(savingState.value),
            onPressed: () => _onPressed(context),
            // Aha! copy: always a back arrow (a spinner while saving), so
            // it reads as "back" and does what back does.
            icon: switch (savingState.value) {
              .saving => const AdaptiveCircularProgressIndicator(),
              _ => const Icon(Icons.arrow_back),
            },
          ),
        );
      },
    );
  }

  /// Aha! copy: saves if needed, waits for the save, then goes back.
  /// Before, with unsaved changes this button only saved.
  Future<void> _onPressed(BuildContext context) async {
    if (savingState.value == .waitingToSave) await triggerSave();
    while (context.mounted && savingState.value == .saving) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!context.mounted || savingState.value != .saved) return;
    _back(context);
  }

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    final isWhiteboard = !navigator.canPop();
    if (isWhiteboard) {
      // if on whiteboard, go to "recents" tab of home screen
      context.go(HomeRoutes.routes[0].path);
    } else {
      navigator.pop();
    }
  }
}

enum SavingState { waitingToSave, saving, saved }
