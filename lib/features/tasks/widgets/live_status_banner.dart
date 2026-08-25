import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/workshop_task.dart';
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
    } else if (mounted) {
      setState(() => _elapsed = Duration.zero);
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
    final activeTask = _activeTask;
    if (activeTask == null) return const SizedBox.shrink();

    final themeColor = context.appColors.success;
    final title = activeTask.description;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 7, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(15),
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
          const SizedBox(width: 10),

          // Status & Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('activeTask'),
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
                    color: context.appColors.text,
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
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: context.appColors.background.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _formatDuration(_elapsed),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: themeColor,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
