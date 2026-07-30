import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../data/task_repository.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  List<Map<String, dynamic>> _mrcvRequests = [];
  List<Map<String, dynamic>> _outsourceRequests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (mounted) setState(() => _error = null);
    try {
      final repo = sl<TaskRepository>();
      final results = await Future.wait([
        repo.getMyMrcvRequests(),
        repo.getMyOutsourceRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _mrcvRequests = results[0];
        _outsourceRequests = results[1];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = context.tr('requestsLoadError');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('myRequests'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(
                context.tr('requestHubSubtitle'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.tr('refreshRequests'),
              onPressed: _isLoading ? null : _loadRequests,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _SummaryHeader(
              materialCount: _mrcvRequests.length,
              outsourceCount: _outsourceRequests.length,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: context.tr('materials')),
                    Tab(text: context.tr('outsource')),
                  ],
                ),
              ),
            ),
            if (_error != null)
              _ErrorBanner(message: _error!, onRetry: _loadRequests),
            Expanded(
              child: _isLoading
                  ? const _RequestSkeleton()
                  : TabBarView(
                      children: [
                        _RequestList(
                          requests: _mrcvRequests,
                          type: _RequestType.material,
                          onRefresh: _loadRequests,
                        ),
                        _RequestList(
                          requests: _outsourceRequests,
                          type: _RequestType.outsource,
                          onRefresh: _loadRequests,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RequestType { material, outsource }

class _SummaryHeader extends StatelessWidget {
  final int materialCount;
  final int outsourceCount;
  const _SummaryHeader({
    required this.materialCount,
    required this.outsourceCount,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceHigh, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.inventory_2_outlined,
                  label: context.tr('materials'),
                  value: materialCount,
                  color: AppColors.warning,
                ),
              ),
              Container(width: 1, height: 42, color: AppColors.border),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.north_east_rounded,
                  label: context.tr('outsource'),
                  value: outsourceCount,
                  color: const Color(0xFFFF8A5B),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      );
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final _RequestType type;
  final Future<void> Function() onRefresh;
  const _RequestList({
    required this.requests,
    required this.type,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .43,
              child: _EmptyState(type: type),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: requests.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _RequestCard(request: requests[index], type: type),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final _RequestType type;
  const _RequestCard({required this.request, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = _textValue(request['name'], context.tr('unnamedRequest'));
    final state = _textValue(request['state'], 'pending');
    final date = _textValue(
      type == _RequestType.material ? request['create_date'] : request['date'],
      '',
    );
    final job = _relationName(
        request['workshop_order_id'], context.tr('jobNotSpecified'));
    final status = _RequestStatus.from(context, state);
    final accent = type == _RequestType.material
        ? AppColors.warning
        : const Color(0xFFFF8A5B);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              type == _RequestType.material
                  ? Icons.inventory_2_outlined
                  : Icons.north_east_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  job,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textSubtle),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                            color: AppColors.textSubtle, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _textValue(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) return value;
    return fallback;
  }

  static String _relationName(dynamic value, String fallback) {
    if (value is List && value.length > 1) return value[1].toString();
    return fallback;
  }

  static String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (parsed == null) return raw.split(' ').first;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }
}

class _RequestStatus {
  final String label;
  final Color color;
  const _RequestStatus(this.label, this.color);

  factory _RequestStatus.from(BuildContext context, String state) {
    return switch (state.toLowerCase()) {
      'approved' ||
      'done' =>
        _RequestStatus(context.tr('approved'), AppColors.success),
      'rejected' ||
      'cancel' ||
      'cancelled' =>
        _RequestStatus(context.tr('rejected'), AppColors.danger),
      'pending' => _RequestStatus(context.tr('pending'), AppColors.warning),
      'submitted' => _RequestStatus(context.tr('submitted'), AppColors.primary),
      'draft' => _RequestStatus(context.tr('draft'), AppColors.textMuted),
      _ => _RequestStatus(_titleCase(state), AppColors.textMuted),
    };
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return 'Unknown';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class _StatusPill extends StatelessWidget {
  final _RequestStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            color: status.color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final _RequestType type;
  const _EmptyState({required this.type});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  type == _RequestType.material
                      ? Icons.inventory_2_outlined
                      : Icons.north_east_rounded,
                  color: AppColors.textSubtle,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                type == _RequestType.material
                    ? context.tr('noMaterialRequests')
                    : context.tr('noOutsourceRequests'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('newRequestsHint'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _RequestSkeleton extends StatelessWidget {
  const _RequestSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          height: 112,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
}
