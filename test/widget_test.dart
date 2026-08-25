import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workshop_mechanic/core/theme/app_theme.dart';
import 'package:workshop_mechanic/features/tasks/domain/models/workshop_task.dart';
import 'package:workshop_mechanic/features/tasks/widgets/task_card.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('task card renders its primary action in ${mode.name} mode',
        (tester) async {
      const task = WorkshopTask(
        id: 42,
        description: 'Inspect and replace front brake pads',
        status: 'assigned',
        estimatedHours: 1.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Scaffold(
            body: TaskCard(
              task: task,
              isProcessing: false,
              onStartTimer: () {},
              onStopTimer: () {},
              onMarkDone: () {},
            ),
          ),
        ),
      );

      expect(find.text('Inspect and replace front brake pads'), findsOneWidget);
      expect(find.text('Assigned'), findsOneWidget);
      expect(find.text('Start work'), findsOneWidget);
      expect(find.text('1.5 h'), findsOneWidget);
      expect(find.text('0 h'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      final context = tester.element(find.byType(TaskCard));
      expect(
        context.appColors.background,
        mode == ThemeMode.light
            ? AppPalette.light.background
            : AppPalette.dark.background,
      );
    });
  }
}
