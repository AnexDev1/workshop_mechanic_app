import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../data/task_repository.dart';
import '../pages/my_requests_page.dart';

class MechanicDrawer extends StatefulWidget {
  final VoidCallback onLogout;
  const MechanicDrawer({super.key, required this.onLogout});

  @override
  State<MechanicDrawer> createState() => _MechanicDrawerState();
}

class _MechanicDrawerState extends State<MechanicDrawer> {
  Map<String, dynamic>? _performance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _performance = sl<TaskRepository>().getCachedMechanicPerformance();
    _loading = _performance == null;
    _loadPerformance();
  }

  Future<void> _loadPerformance() async {
    try {
      final data = await sl<TaskRepository>().getMechanicPerformance();
      if (mounted) setState(() => _performance = data);
    } catch (_) {
      // Keep the last persisted snapshot visible when refresh fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _performance?['name'] as String? ?? 'Mechanic';
    final section =
        _performance?['section'] as String? ?? 'Workshop technician';
    final working = (_performance?['working_hours'] as num?)?.toDouble() ?? 0;
    final idle = (_performance?['idle_hours'] as num?)?.toDouble() ?? 0;
    final efficiency = (_performance?['efficiency'] as num?)?.toDouble() ?? 0;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * .88,
      backgroundColor: context.appColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(
              name: name,
              section: section,
              onClose: () => Navigator.pop(context),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _SectionHeader(
                    title: context.tr('todaySnapshot'),
                    trailing: IconButton(
                      tooltip: 'Refresh performance',
                      onPressed: () {
                        setState(() => _loading = true);
                        _loadPerformance();
                      },
                      icon: Icon(Icons.refresh_rounded,
                          size: 18, color: context.appColors.textMuted),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _loading
                        ? const SizedBox(
                            height: 132,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _PerformanceCard(
                            working: working,
                            idle: idle,
                            efficiency: efficiency,
                          ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: context.tr('navigation')),
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    title: context.tr('taskDashboard'),
                    subtitle: context.tr('taskDashboardSubtitle'),
                    isActive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _NavItem(
                    icon: Icons.assignment_outlined,
                    title: context.tr('myRequests'),
                    subtitle: context.tr('requestsSubtitle'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MyRequestsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appColors.danger,
                  side: BorderSide(
                      color: context.appColors.danger.withValues(alpha: .35)),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onLogout();
                },
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: Text(context.tr('logout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String section;
  final VoidCallback onClose;
  const _ProfileHeader({
    required this.name,
    required this.section,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.appColors.primary, const Color(0xFF785CFF)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.primary.withValues(alpha: .2),
                    blurRadius: 18,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                name.isEmpty ? 'M' : name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.appColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close menu',
              onPressed: onClose,
              icon:
                  Icon(Icons.close_rounded, color: context.appColors.textMuted),
            ),
          ],
        ),
      );
}

class _PerformanceCard extends StatelessWidget {
  final double working;
  final double idle;
  final double efficiency;
  const _PerformanceCard({
    required this.working,
    required this.idle,
    required this.efficiency,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.appColors.surfaceHigh, context.appColors.surface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: _Metric(
                        label: context.tr('working'),
                        value: '${working.toStringAsFixed(1)}h',
                        color: context.appColors.success)),
                Container(
                    width: 1, height: 38, color: context.appColors.border),
                Expanded(
                    child: _Metric(
                        label: context.tr('idle'),
                        value: '${idle.toStringAsFixed(1)}h',
                        color: context.appColors.warning)),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Text(context.tr('dailyEfficiency'),
                    style: TextStyle(
                        color: context.appColors.textMuted, fontSize: 11)),
                const Spacer(),
                Text(
                  '${efficiency.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: context.appColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (efficiency / 100).clamp(0, 1),
                minHeight: 7,
                backgroundColor: context.appColors.background,
              ),
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 9),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.appColors.textSubtle,
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: context.appColors.textSubtle,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 21, fontWeight: FontWeight.w800)),
        ],
      );
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isActive;
  const _NavItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          tileColor: isActive
              ? context.appColors.primarySoft.withValues(alpha: .65)
              : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive
                  ? context.appColors.primary
                  : context.appColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon,
                color: isActive ? Colors.white : context.appColors.primary,
                size: 20),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle,
              style:
                  TextStyle(fontSize: 11, color: context.appColors.textSubtle)),
          trailing: Icon(
            isActive ? Icons.circle : Icons.chevron_right_rounded,
            size: isActive ? 7 : 22,
            color: isActive
                ? context.appColors.primary
                : context.appColors.textSubtle,
          ),
          onTap: onTap,
        ),
      );
}
