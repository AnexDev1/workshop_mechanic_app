import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/workshop_task.dart';
import '../data/task_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_locale.dart';

class LiveStatusBanner extends StatefulWidget {
  final List<WorkshopTask> tasks;

  const LiveStatusBanner({super.key, required this.tasks});

  @override
  State<LiveStatusBanner> createState() => _LiveStatusBannerState();
}

class _LiveStatusBannerState extends State<LiveStatusBanner> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  WorkshopTask? _activeTask;

  @override
  void initState() {
    super.initState();
    _checkActiveState();
  }

  @override
  void didUpdateWidget(LiveStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkActiveState();
  }

  Future<void> _checkActiveState() async {
    _ticker?.cancel();
    final active = widget.tasks.cast<WorkshopTask?>().firstWhere(
          (t) => t != null && t.isWorking,
          orElse: () => null,
        );

    if (mounted) {
      setState(() {
        _activeTask = active;
      });
    }

    if (active != null && active.currentLogStart != null) {
      // Task timer mode: count up from task start
      _elapsed =
          DateTime.now().toUtc().difference(active.currentLogStart!.toUtc());
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });
    } else {
      // Idle / Off-time mode: count up from total accumulated idle time today
      try {
        final repo = sl<TaskRepository>();
        final perf = await repo.getMechanicPerformance();
        final idleHours = (perf['idle_hours'] as num?)?.toDouble() ?? 0.0;
        final initialIdleSeconds = (idleHours * 3600).round();

        if (mounted) {
          setState(() {
            _elapsed = Duration(seconds: initialIdleSeconds);
          });
        }
      } catch (_) {}

      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed += const Duration(seconds: 1));
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isWorking = _activeTask != null;
    final themeColor = isWorking ? AppColors.success : AppColors.warning;
    final title =
        isWorking ? _activeTask!.description : context.tr('waitingTask');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: .24)),
      ),
      child: Row(
        children: [
          // Pulse Indicator Dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: themeColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: .6),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Status & Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWorking
                      ? context.tr('activeTask')
                      : context.tr('available'),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Live Ticker Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatDuration(_elapsed),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: themeColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
