import 'package:flutter_test/flutter_test.dart';
import 'package:focuslock_mobile/core/models/task_item.dart';
import 'package:focuslock_mobile/core/providers/schedule_provider.dart';
import 'package:focuslock_mobile/main.dart';

void main() {
  testWidgets('FocusLockApp smoke test and Spanish tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const FocusLockApp());
    expect(find.text('FocusLock'), findsOneWidget);
    expect(find.text('Enfoque'), findsOneWidget);
    expect(find.text('Horario'), findsOneWidget);
    expect(find.text('Métricas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  test('ScheduleProvider task management test', () {
    final provider = ScheduleProvider();
    final initialCount = provider.allTasks.length;

    final newTask = TaskItem(
      id: 'test-1',
      title: 'Prueba de Tarea',
      category: TaskCategory.university,
      date: DateTime.now(),
      startTime: '08:00 AM',
      endTime: '09:00 AM',
      durationMinutes: 60,
      isCompleted: false,
    );

    provider.addTask(newTask);
    expect(provider.allTasks.length, initialCount + 1);

    provider.toggleTaskCompleted('test-1');
    final updated = provider.allTasks.firstWhere((t) => t.id == 'test-1');
    expect(updated.isCompleted, true);

    provider.deleteTask('test-1');
    expect(provider.allTasks.length, initialCount);
  });
}
