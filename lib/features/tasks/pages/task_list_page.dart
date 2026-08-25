import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import '../bloc/task_bloc.dart';
import '../widgets/task_card.dart';
import '../widgets/outsource_dialog.dart';
import '../widgets/mrcv_dialog.dart';
import '../widgets/mechanic_drawer.dart';
import '../widgets/live_status_banner.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_manager.dart';
import '../../../core/localization/app_locale.dart';
import '../data/task_repository.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  String _filter = 'all';
  Timer? _refreshTimer;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;

  bool _isCheckedIn = false;
  bool _isUpdatingDutyStatus = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  bool _isOnline = SyncManager().isOnline;
  String? _lastAutoSyncFailure;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkDutyStatus();
    _updatePendingSyncCount();
    _connectionSubscription = SyncManager().connectionChanges.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    _syncResultSubscription = SyncManager().syncResults.listen((result) {
      if (!mounted) return;
      setState(() => _pendingSyncCount = result.remainingCount);
      if (result.failureKind != null && !_isSyncing) {
        final signature = '${result.failureKind}:${result.failedActionType}';
        if (_lastAutoSyncFailure != signature) {
          _lastAutoSyncFailure = signature;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_syncFailureMessage(result)),
            duration: const Duration(seconds: 8),
            backgroundColor: context.appColors.danger,
          ));
        }
      } else if (result.failureKind == null) {
        _lastAutoSyncFailure = null;
      }
      if (result.syncedCount > 0 && !_isSyncing) {
        context.read<TaskBloc>().add(LoadTasks(
              statusFilter: _filter,
              isAvailable: false,
              showLoading: false,
            ));
      }
    });
    // Auto-refresh every 30 seconds to update live timers
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<TaskBloc>().add(LoadTasks(
              statusFilter: _filter,
              isAvailable: false,
              showLoading: false,
            ));
        _updatePendingSyncCount();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectionSubscription?.cancel();
    _syncResultSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkDutyStatus() async {
    final status = await sl<TaskRepository>().getDutyStatus();
    if (mounted) {
      setState(() {
        _isCheckedIn = status['is_checked_in'] == true;
      });
    }
  }

  void _loadTasks() {
    context
        .read<TaskBloc>()
        .add(LoadTasks(statusFilter: _filter, isAvailable: false));
  }

  Future<void> _refreshTasks() async {
    final bloc = context.read<TaskBloc>();
    final refreshed = bloc.stream.firstWhere(
      (state) => state is TaskLoaded || state is TaskError,
    );

    bloc.add(LoadTasks(
      statusFilter: _filter,
      isAvailable: false,
      showLoading: false,
    ));

    await refreshed;
    await _updatePendingSyncCount();
  }

  Future<void> _updatePendingSyncCount() async {
    final count = await sl<TaskRepository>().getPendingSyncCount();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final result = await sl<TaskRepository>()
          .syncPendingActions()
          .timeout(const Duration(seconds: 45));
      if (!mounted) return;

      setState(() => _pendingSyncCount = result.remainingCount);

      if (!result.hasNetwork) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('noNetwork')),
        ));
        return;
      }

      // Refresh in the background. A slow Odoo read must not leave the manual
      // sync button stuck after the queue operation itself has completed.
      context.read<TaskBloc>().add(LoadTasks(
            statusFilter: _filter,
            isAvailable: false,
            showLoading: false,
          ));

      final message = result.failureKind != null
          ? _syncFailureMessage(result)
          : result.remainingCount == 0
              ? result.syncedCount == 0
                  ? context.tr('alreadyUpToDate')
                  : context.tr('syncSuccess', {'count': result.syncedCount})
              : context.tr('syncPartial', {
                  'synced': result.syncedCount,
                  'remaining': result.remainingCount,
                });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        duration: Duration(
          seconds: result.failureKind == null ? 4 : 8,
        ),
        backgroundColor: result.failureKind != null
            ? context.appColors.danger
            : result.remainingCount == 0
                ? context.appColors.success
                : context.appColors.warning,
      ));
    } on TimeoutException {
      if (!mounted) return;
      await _updatePendingSyncCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('syncTimedOut')),
        duration: const Duration(seconds: 6),
        backgroundColor: context.appColors.warning,
      ));
    } catch (_) {
      if (!mounted) return;
      await _updatePendingSyncCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.tr('syncFailed')),
      ));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String _syncActionLabel(String? actionType) {
    return switch (actionType) {
      'check_in' => context.tr('checkIn'),
      'check_out' => context.tr('checkOut'),
      'start_timer' => context.tr('startWork'),
      'stop_timer' => context.tr('stopWorkTimer'),
      'mark_done' => context.tr('complete'),
      'claim' => context.tr('takeTask'),
      _ => context.tr('syncAction'),
    };
  }

  String _syncFailureMessage(SyncResult result) {
    final key = result.failureKind == SyncFailureKind.permissionDenied
        ? 'syncPermissionDenied'
        : 'syncServerRejected';
    return context.tr(key, {
      'action': _syncActionLabel(result.failedActionType),
    });
  }

  Future<void> _performDutyToggle() async {
    if (_isUpdatingDutyStatus) return;

    setState(() => _isUpdatingDutyStatus = true);

    try {
      final biometric = LocalAuthentication();
      final supported = await biometric.canCheckBiometrics ||
          await biometric.isDeviceSupported();
      if (!supported ||
          !await biometric.authenticate(
            localizedReason: _isCheckedIn
                ? 'Authenticate to check out'
                : 'Authenticate to check in',
            options: const AuthenticationOptions(
                biometricOnly: true, stickyAuth: true),
          )) throw StateError('Fingerprint authorization was not completed.');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationPrompt(
          title: context.tr('turnOnLocation'),
          message: context.tr('locationOffMessage'),
          actionLabel: context.tr('locationSettings'),
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        await _showLocationPrompt(
          title: context.tr('locationPermissionNeeded'),
          message: context.tr('locationPermissionMessage'),
          actionLabel: context.tr('tryAgain'),
          onAction: Geolocator.requestPermission,
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await _showLocationPrompt(
          title: context.tr('allowLocation'),
          message: context.tr('locationBlockedMessage'),
          actionLabel: context.tr('appSettings'),
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        await Geolocator.openAppSettings();
        throw StateError(
            'Enable Precise location in app settings, then try again.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Getting GPS location (internet is not required)...'),
          duration: Duration(seconds: 3)));

      final position = await _getPreciseLocation();

      final repo = sl<TaskRepository>();
      final isOnlineSync = _isCheckedIn
          ? await repo.checkOut(position.latitude, position.longitude)
          : await repo.checkIn(position.latitude, position.longitude);

      if (!mounted) return;
      final actionText = _isCheckedIn ? 'Check-out' : 'Check-in';
      setState(() {
        _isCheckedIn = !_isCheckedIn;
        _isUpdatingDutyStatus = false;
      });
      await _updatePendingSyncCount();
      if (!mounted) return;

      final statusMsg = isOnlineSync
          ? '$actionText synced successfully!'
          : '$actionText saved offline. Will sync when connected.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isOnlineSync ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(statusMsg)),
            ],
          ),
          backgroundColor: isOnlineSync
              ? context.appColors.success
              : context.appColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is TimeoutException
          ? 'Could not get a precise GPS signal. Move outdoors and try again.'
          : e is StateError
              ? e.message
              : e.toString().toLowerCase().contains('no technical record')
                  ? 'Your Odoo account is not linked to a workshop technician record. Ask an administrator to link your user account before checking in.'
                  : 'Location failed: ${e.toString().replaceFirst('Exception: ', '')}';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted && _isUpdatingDutyStatus) {
        setState(() => _isUpdatingDutyStatus = false);
      }
    }
  }

  Future<Position> _getPreciseLocation() async {
    final fused = await _bestFreshFix(
      Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: const Duration(seconds: 15),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 15),
            ),
    );
    if (fused != null) return fused;

    if (Platform.isAndroid) {
      // Offline fallback: direct hardware GPS. No cached position is used.
      final gps = await _bestFreshFix(AndroidSettings(
        forceLocationManager: true,
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 20),
      ));
      if (gps != null) return gps;
    }
    throw TimeoutException(
        'A fresh GPS fix with 5 metre accuracy was not available.');
  }

  Future<Position?> _bestFreshFix(LocationSettings settings) async {
    Position? best;
    StreamSubscription<Position>? subscription;
    Timer? timeout;
    final result = Completer<Position?>();

    void finish() {
      if (!result.isCompleted) result.complete(best);
      timeout?.cancel();
      subscription?.cancel();
    }

    subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      if (best == null || position.accuracy < best!.accuracy) best = position;
      if (position.accuracy <= 5) finish();
    }, onError: (_) => finish());
    timeout = Timer(const Duration(seconds: 120), finish);
    return result.future;
  }

  Future<void> _showLocationPrompt({
    required String title,
    required String message,
    required String actionLabel,
    required Future<dynamic> Function() onAction,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MechanicDrawer(
        onLogout: () => context.read<AuthBloc>().add(LogoutRequested()),
      ),
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('workshop'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(
              DateFormat('EEEE, d MMMM').format(DateTime.now()),
              style: TextStyle(
                fontSize: 11,
                color: context.appColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.tr('language'),
            initialValue: AppLocaleController.instance.value,
            onSelected: AppLocaleController.instance.setLanguage,
            position: PopupMenuPosition.under,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'en', child: Text('EN')),
              PopupMenuItem(value: 'am', child: Text('AM')),
              PopupMenuItem(value: 'om', child: Text('OM')),
            ],
            child: Container(
              constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              alignment: Alignment.center,
              child: Text(
                AppLocaleController.instance.value.toUpperCase(),
                style: TextStyle(
                  color: context.appColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeController,
            builder: (context, mode, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                tooltip: isDark
                    ? context.tr('switchToLight')
                    : context.tr('switchToDark'),
                onPressed: () => appThemeController
                    .setMode(isDark ? ThemeMode.light : ThemeMode.dark),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      RotationTransition(turns: animation, child: child),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: _isOnline
                ? context.tr('refreshTasks')
                : context.tr('refreshUnavailableOffline'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isOnline ? _refreshTasks : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildShiftPanel(),
          _buildFilterBar(),
          Expanded(
            child: BlocConsumer<TaskBloc, TaskState>(
              listener: (context, state) {
                if (state is TaskLoaded || state is TaskError) {
                  _updatePendingSyncCount();
                }
              },
              builder: (ctx, state) {
                if (state is TaskLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: context.appColors.primary),
                  );
                }
                if (state is TaskError) {
                  return _buildRefreshableStatus(_buildError(state.message));
                }
                if (state is TaskLoaded) {
                  // If the mode was switched while loading or state updated from action, sync UI
                  WidgetsBinding.instance.addPostFrameCallback((_) {});
                  if (state.tasks.isEmpty) {
                    return _buildRefreshableStatus(_buildEmpty());
                  }
                  return Column(
                    children: [
                      if (!state.isAvailableMode)
                        LiveStatusBanner(tasks: state.tasks),
                      Expanded(
                        child: _OfflineAwareRefresh(
                          isOnline: _isOnline,
                          onRefresh: _refreshTasks,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              32 + MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: state.tasks.length,
                            itemBuilder: (ctx, i) {
                              final task = state.tasks[i];
                              final isProcessing =
                                  state.processingTaskId == task.id;
                              return TaskCard(
                                task: task,
                                isProcessing: isProcessing,
                                onTakeTask: state.isAvailableMode
                                    ? () => context
                                        .read<TaskBloc>()
                                        .add(TakeTaskEvent(task.id))
                                    : null,
                                onStartTimer: () => context
                                    .read<TaskBloc>()
                                    .add(StartTimerEvent(task.id)),
                                onStopTimer: () => context
                                    .read<TaskBloc>()
                                    .add(StopTimerEvent(task.id)),
                                onMarkDone: () => context
                                    .read<TaskBloc>()
                                    .add(MarkTaskDoneEvent(task.id)),
                                onRequestOutsource: task.jobId != null
                                    ? () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              OutsourceDialog(task: task),
                                        )
                                    : null,
                                onRequestMrcv: task.jobId != null
                                    ? () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              MrcvDialog(task: task),
                                        ).then((res) {
                                          if (res == true) _loadTasks();
                                        })
                                    : null,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftPanel() {
    final hasPending = _pendingSyncCount > 0;
    final dutyColor =
        _isCheckedIn ? context.appColors.success : context.appColors.textMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.appColors.surfaceHigh, context.appColors.surface],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: dutyColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isCheckedIn
                        ? Icons.location_on_rounded
                        : Icons.location_off_outlined,
                    color: dutyColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCheckedIn
                            ? context.tr('shiftActive')
                            : context.tr('offDuty'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isCheckedIn
                            ? context.tr('locationRecorded')
                            : context.tr('checkInHint'),
                        style: TextStyle(
                            color: context.appColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ConnectionPill(isOnline: _isOnline),
                    if (hasPending) ...[
                      const SizedBox(height: 5),
                      Text(
                        context
                            .tr('pendingCount', {'count': _pendingSyncCount}),
                        style: TextStyle(
                          color: context.appColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isUpdatingDutyStatus ? null : _performDutyToggle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCheckedIn
                          ? context.appColors.danger.withValues(alpha: .14)
                          : context.appColors.success,
                      foregroundColor: _isCheckedIn
                          ? context.appColors.danger
                          : context.appColors.background,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: _isUpdatingDutyStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isCheckedIn
                            ? Icons.logout_rounded
                            : Icons.my_location_rounded),
                    label: Text(_isUpdatingDutyStatus
                        ? context.tr('gettingGps')
                        : _isCheckedIn
                            ? context.tr('checkOut')
                            : context.tr('checkIn')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _syncNow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hasPending
                          ? context.appColors.warning
                          : context.appColors.textMuted,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 19),
                    label: Text(_isSyncing
                        ? context.tr('syncing')
                        : context.tr('sync')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshableStatus(Widget child) {
    return _OfflineAwareRefresh(
      isOnline: _isOnline,
      onRefresh: _refreshTasks,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight, child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('all', context.tr('all')),
      ('assigned', context.tr('assigned')),
      ('working', context.tr('inProgress')),
      ('completed', context.tr('completed')),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
        children: filters.map((f) {
          final active = _filter == f.$1;
          return GestureDetector(
            onTap: () {
              setState(() => _filter = f.$1);
              _loadTasks();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
              decoration: BoxDecoration(
                color:
                    active ? context.appColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? context.appColors.primary
                      : context.appColors.border,
                ),
              ),
              child: Text(
                f.$2,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? context.appColors.primary
                      : context.appColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: context.appColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: context.appColors.textMuted, fontSize: 14)),
              const SizedBox(height: 20),
              TextButton(
                  onPressed: _loadTasks, child: Text(context.tr('retry'))),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_alt_rounded,
                size: 64, color: context.appColors.textSubtle),
            const SizedBox(height: 16),
            Text(context.tr('noTasks'),
                style: GoogleFonts.inter(
                    color: context.appColors.textMuted, fontSize: 16)),
          ],
        ),
      );
}

class _OfflineAwareRefresh extends StatelessWidget {
  final bool isOnline;
  final Future<void> Function() onRefresh;
  final Widget child;

  const _OfflineAwareRefresh({
    required this.isOnline,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return child;
    return RefreshIndicator(
      color: context.appColors.primary,
      backgroundColor: context.appColors.surface,
      onRefresh: onRefresh,
      child: child,
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final bool isOnline;
  const _ConnectionPill({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color =
        isOnline ? context.appColors.success : context.appColors.danger;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? context.tr('online') : context.tr('offline'),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
