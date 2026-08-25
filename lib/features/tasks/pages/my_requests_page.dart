import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/sync/sync_manager.dart';
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
  bool _isOnline = SyncManager().isOnline;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    final repository = sl<TaskRepository>();
    _mrcvRequests = repository.getCachedMrcvRequests();
    _outsourceRequests = repository.getCachedOutsourceRequests();
    _isLoading = _mrcvRequests.isEmpty && _outsourceRequests.isEmpty;
    _connectionSubscription = SyncManager().connectionChanges.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
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
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.tr('refreshRequests'),
              onPressed: _isLoading || !_isOnline ? null : _loadRequests,
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
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: context.appColors.border),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: context.appColors.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  labelColor: context.appColors.primary,
                  unselectedLabelColor: context.appColors.textMuted,
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
                          isOnline: _isOnline,
                        ),
                        _RequestList(
                          requests: _outsourceRequests,
                          type: _RequestType.outsource,
                          onRefresh: _loadRequests,
                          isOnline: _isOnline,
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.appColors.surfaceHigh,
                context.appColors.surface
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.appColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.inventory_2_outlined,
                  label: context.tr('materials'),
                  value: materialCount,
                  color: context.appColors.warning,
                ),
              ),
              Container(width: 1, height: 42, color: context.appColors.border),
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
                  style: TextStyle(
                      color: context.appColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      );
}

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final _RequestType type;
  final Future<void> Function() onRefresh;
  final bool isOnline;
  const _RequestList({
    required this.requests,
    required this.type,
    required this.onRefresh,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      final list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * .43,
            child: _EmptyState(type: type),
          ),
        ],
      );
      return isOnline
          ? RefreshIndicator(onRefresh: onRefresh, child: list)
          : list;
    }

    final list = ListView.separated(
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
    );
    return isOnline
        ? RefreshIndicator(onRefresh: onRefresh, child: list)
        : list;
  }
}

class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final _RequestType type;
  const _RequestCard({required this.request, required this.type});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final type = widget.type;
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
        ? context.appColors.warning
        : const Color(0xFFFF8A5B);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: context.appColors.border),
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
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                if (type == _RequestType.material)
                  _buildMaterialLines(context, request),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 13, color: context.appColors.textSubtle),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                            color: context.appColors.textSubtle, fontSize: 11),
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

  Widget _buildMaterialLines(
      BuildContext context, Map<String, dynamic> request) {
    final rawLines = request['material_lines'];
    if (rawLines is! List || rawLines.isEmpty) return const SizedBox.shrink();
    final lines = rawLines.whereType<Map<String, dynamic>>().toList();
    final visibleLines = _expanded ? lines : lines.take(2).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.appColors.surfaceHigh,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 14, color: context.appColors.warning),
              const SizedBox(width: 6),
              Text(
                context.tr('submittedMaterials'),
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                context.tr('itemCount', {'count': lines.length}),
                style:
                    TextStyle(color: context.appColors.textSubtle, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...visibleLines.map((line) => _MaterialLineRow(line: line)),
          if (lines.length > 2)
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? context.tr('showLess')
                          : context
                              .tr('viewAllMaterials', {'count': lines.length}),
                      style: TextStyle(
                        color: context.appColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: context.appColors.primary,
                      size: 16,
                    ),
                  ],
                ),
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

class _MaterialLineRow extends StatelessWidget {
  final Map<String, dynamic> line;
  const _MaterialLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final product =
        _relationLabel(line['product_id'], context.tr('unnamedMaterial'));
    final unit = _relationLabel(line['uom_id'], '');
    final requested = (line['quantity'] as num?)?.toDouble() ?? 0;
    final issued = (line['issued_qty'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
                color: context.appColors.warning, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product,
              style: TextStyle(
                color: context.appColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${requested.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  color: context.appColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (issued > 0)
                Text(
                  context.tr('issuedQuantity',
                      {'quantity': issued.toStringAsFixed(2)}),
                  style:
                      TextStyle(color: context.appColors.success, fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _relationLabel(dynamic relation, String fallback) {
    if (relation is List && relation.length > 1) {
      return relation[1].toString();
    }
    return fallback;
  }
}

class _RequestStatus {
  final String label;
  final Color color;
  _RequestStatus(this.label, this.color);

  factory _RequestStatus.from(BuildContext context, String state) {
    return switch (state.toLowerCase()) {
      'approved' ||
      'done' =>
        _RequestStatus(context.tr('approved'), context.appColors.success),
      'rejected' ||
      'cancel' ||
      'cancelled' =>
        _RequestStatus(context.tr('rejected'), context.appColors.danger),
      'pending' =>
        _RequestStatus(context.tr('pending'), context.appColors.warning),
      'submitted' =>
        _RequestStatus(context.tr('submitted'), context.appColors.primary),
      'draft' =>
        _RequestStatus(context.tr('draft'), context.appColors.textMuted),
      _ => _RequestStatus(_titleCase(state), context.appColors.textMuted),
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
                  color: context.appColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Icon(
                  type == _RequestType.material
                      ? Icons.inventory_2_outlined
                      : Icons.north_east_rounded,
                  color: context.appColors.textSubtle,
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
                style: TextStyle(
                  color: context.appColors.textMuted,
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
          color: context.appColors.danger.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: context.appColors.danger.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded,
                color: context.appColors.danger, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: context.appColors.textMuted, fontSize: 11)),
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
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: context.appColors.border),
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
