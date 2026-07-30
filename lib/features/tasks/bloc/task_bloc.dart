import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/task_repository.dart';
import '../domain/models/workshop_task.dart';

// ── Events ────────────────────────────────────────────────────────────────────
abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String? statusFilter;
  final bool isAvailable;
  final bool showLoading;
  const LoadTasks({
    this.statusFilter,
    this.isAvailable = false,
    this.showLoading = true,
  });
  @override
  List<Object?> get props => [statusFilter, isAvailable, showLoading];
}

class StartTimerEvent extends TaskEvent {
  final int taskId;
  const StartTimerEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

class StopTimerEvent extends TaskEvent {
  final int taskId;
  const StopTimerEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

class MarkTaskDoneEvent extends TaskEvent {
  final int taskId;
  const MarkTaskDoneEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

class TakeTaskEvent extends TaskEvent {
  final int taskId;
  const TakeTaskEvent(this.taskId);
  @override
  List<Object?> get props => [taskId];
}

// ── States ────────────────────────────────────────────────────────────────────
abstract class TaskState extends Equatable {
  const TaskState();
  @override
  List<Object?> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<WorkshopTask> tasks;
  final int? processingTaskId;
  final bool isAvailableMode;

  const TaskLoaded({
    required this.tasks,
    this.processingTaskId,
    this.isAvailableMode = false,
  });

  @override
  List<Object?> get props => [tasks, processingTaskId, isAvailableMode];
}

class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _repo;

  TaskBloc({required TaskRepository repo})
      : _repo = repo,
        super(TaskInitial()) {
    on<LoadTasks>(_onLoad);
    on<StartTimerEvent>(_onStartTimer);
    on<StopTimerEvent>(_onStopTimer);
    on<MarkTaskDoneEvent>(_onMarkDone);
    on<TakeTaskEvent>(_onTakeTask);
  }

  Future<void> _onLoad(LoadTasks event, Emitter<TaskState> emit) async {
    if (event.showLoading) emit(TaskLoading());
    try {
      final tasks = event.isAvailable
          ? await _repo.getAvailableTasks()
          : await _repo.getMyTasks(statusFilter: event.statusFilter);
      emit(TaskLoaded(tasks: tasks, isAvailableMode: event.isAvailable));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onStartTimer(
      StartTimerEvent event, Emitter<TaskState> emit) async {
    final current = state;
    if (current is TaskLoaded) {
      emit(TaskLoaded(tasks: current.tasks, processingTaskId: event.taskId));
      try {
        await _repo.startTimer(event.taskId);
        final tasks = await _repo.getMyTasks();
        emit(TaskLoaded(tasks: tasks));
      } catch (e) {
        emit(TaskError(e.toString()));
      }
    }
  }

  Future<void> _onStopTimer(
      StopTimerEvent event, Emitter<TaskState> emit) async {
    final current = state;
    if (current is TaskLoaded) {
      emit(TaskLoaded(tasks: current.tasks, processingTaskId: event.taskId));
      try {
        await _repo.stopTimer(event.taskId);
        final tasks = await _repo.getMyTasks();
        emit(TaskLoaded(tasks: tasks));
      } catch (e) {
        emit(TaskError(e.toString()));
      }
    }
  }

  Future<void> _onMarkDone(
      MarkTaskDoneEvent event, Emitter<TaskState> emit) async {
    final current = state;
    if (current is TaskLoaded) {
      emit(TaskLoaded(
          tasks: current.tasks,
          processingTaskId: event.taskId,
          isAvailableMode: current.isAvailableMode));
      try {
        await _repo.markTaskDone(event.taskId);
        final tasks = current.isAvailableMode
            ? await _repo.getAvailableTasks()
            : await _repo.getMyTasks();
        emit(
            TaskLoaded(tasks: tasks, isAvailableMode: current.isAvailableMode));
      } catch (e) {
        emit(TaskError(e.toString()));
      }
    }
  }

  Future<void> _onTakeTask(TakeTaskEvent event, Emitter<TaskState> emit) async {
    final current = state;
    if (current is TaskLoaded) {
      emit(TaskLoaded(
          tasks: current.tasks,
          processingTaskId: event.taskId,
          isAvailableMode: current.isAvailableMode));
      try {
        await _repo.takeTask(event.taskId);
        // After taking a task, automatically switch to My Tasks so they can start it
        final tasks = await _repo.getMyTasks();
        emit(TaskLoaded(tasks: tasks, isAvailableMode: false));
      } catch (e) {
        emit(TaskError(e.toString()));
      }
    }
  }
}
