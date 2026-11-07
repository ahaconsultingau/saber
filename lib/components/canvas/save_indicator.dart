import 'package:material_ui/material_ui.dart';
import 'package:saber/components/theming/adaptive_circular_progress_indicator.dart';
import 'package:saber/data/is_this_a_test.dart';

/// Replaces the back button as the
/// [AppBar.leading] widget in the [AppBar]
/// to indicate the state of saving in the editor.
class SaveIndicator extends StatelessWidget {
  const new({super.key, required this.savingState, required this.onBack});

  final ValueNotifier<SavingState> savingState;

  /// Aha! copy: saves if needed, then leaves (the editor's own
  /// save-then-leave, shared with the system back gesture).
  final VoidCallback onBack;

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
            onPressed: onBack,
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
}

enum SavingState { waitingToSave, saving, saved }
