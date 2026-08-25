import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/theme/app_theme.dart';
import '../data/task_repository.dart';
import '../domain/models/workshop_task.dart';

typedef _MaterialLine = ({
  Map<String, dynamic> product,
  double quantity,
});

class MrcvDialog extends StatefulWidget {
  final WorkshopTask task;
  const MrcvDialog({super.key, required this.task});

  @override
  State<MrcvDialog> createState() => _MrcvDialogState();
}

class _MrcvDialogState extends State<MrcvDialog> {
  final _quantityController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();
  TextEditingController? _autocompleteController;

  bool _loadingContext = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _warehouses = [];
  Map<String, dynamic>? _warehouse;
  Map<String, dynamic>? _selectedProduct;
  final List<_MaterialLine> _items = [];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    try {
      final data =
          await sl<TaskRepository>().getMrcvContext(widget.task.jobId!);
      if (!mounted) return;
      setState(() {
        _warehouses = (data['warehouses'] as List).cast<Map<String, dynamic>>();
        _warehouse = _warehouses.firstOrNull;
      });
    } catch (_) {
      // The empty state below gives the user a retry path.
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
  }

  bool _addSelectedItem() {
    final product = _selectedProduct;
    final quantity = double.tryParse(_quantityController.text.trim());
    if (product == null || quantity == null || quantity <= 0) {
      _showMessage(context.tr('selectProductAndQuantity'), isError: true);
      return false;
    }

    final productId = product['id'];
    final existingIndex =
        _items.indexWhere((line) => line.product['id'] == productId);
    setState(() {
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = (
          product: existing.product,
          quantity: existing.quantity + quantity,
        );
      } else {
        _items.add((product: product, quantity: quantity));
      }
      _selectedProduct = null;
      _quantityController.text = '1';
      _autocompleteController?.clear();
    });
    FocusScope.of(context).unfocus();
    return true;
  }

  Future<void> _submit() async {
    if (_selectedProduct != null && !_addSelectedItem()) return;
    if (_warehouse == null || _items.isEmpty) {
      _showMessage(context.tr('addAtLeastOneProduct'), isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final repository = sl<TaskRepository>();
      await repository.createMrcvRequestItems(
        jobId: widget.task.jobId!,
        warehouseId: _warehouse!['id'] as int,
        items: _items
            .map((line) => {
                  'product_id': line.product['id'],
                  'quantity': line.quantity,
                })
            .toList(),
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            context.tr('materialItemsSubmitted', {'count': _items.length})),
        backgroundColor: context.appColors.success,
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        _showMessage(_materialSubmitError(error), isError: true);
      }
    }
  }

  String _materialSubmitError(Object error) {
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    final normalized = raw.toLowerCase();

    if (normalized.contains('action_create_from_mobile') &&
        (normalized.contains('positional argument') ||
            normalized.contains('unexpected keyword') ||
            normalized.contains('takes '))) {
      return context.tr('materialServerUpdateRequired');
    }
    if (normalized.contains('no approval flow')) {
      return context.tr('materialApprovalFlowMissing');
    }
    if (normalized.contains('no steps defined')) {
      return context.tr('materialApprovalStepsMissing');
    }
    if (normalized.contains('access') ||
        normalized.contains('not allowed') ||
        normalized.contains('permission')) {
      return context.tr('materialPermissionDenied');
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection error') ||
        normalized.contains('timed out') ||
        normalized.contains('network is unreachable')) {
      return context.tr('materialConnectionFailed');
    }

    // Odoo's RPC message is normally concise and useful. Avoid exposing a
    // traceback or an excessively long internal server response in the UI.
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.isNotEmpty &&
        !normalized.contains('traceback') &&
        firstLine.length <= 180) {
      return firstLine;
    }
    return context.tr('materialSubmitFailed');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          isError ? context.appColors.danger : context.appColors.surfaceHigh,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom * .08,
                ),
                child: _buildForm(),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.appColors.warning.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: context.appColors.warning, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('requestMaterial'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  widget.task.jobName ?? widget.task.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.appColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: context.appColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    if (_loadingContext) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_warehouses.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warehouse_outlined,
                  size: 42, color: context.appColors.textSubtle),
              const SizedBox(height: 12),
              Text(context.tr('noWarehouses')),
              TextButton(
                  onPressed: _loadContext, child: Text(context.tr('retry'))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(context.tr('warehouse')),
        const SizedBox(height: 7),
        DropdownButtonFormField<Map<String, dynamic>>(
          initialValue: _warehouse,
          isExpanded: true,
          dropdownColor: context.appColors.surfaceHigh,
          decoration:
              const InputDecoration(prefixIcon: Icon(Icons.warehouse_outlined)),
          items: _warehouses
              .map((warehouse) => DropdownMenuItem(
                    value: warehouse,
                    child: Text(
                      warehouse['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _warehouse = value;
                    _selectedProduct = null;
                    _items.clear();
                    _autocompleteController?.clear();
                  });
                },
        ),
        const SizedBox(height: 16),
        _FieldLabel(context.tr('product')),
        const SizedBox(height: 7),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (option) => option['name'] as String,
          optionsBuilder: (value) async {
            if (value.text.trim().isEmpty || _warehouse == null) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return sl<TaskRepository>().searchWarehouseProducts(
              _warehouse!['lot_stock_id'] as int,
              value.text.trim(),
            );
          },
          onSelected: (selection) =>
              setState(() => _selectedProduct = selection),
          fieldViewBuilder: (context, controller, focusNode, onSubmit) {
            _autocompleteController = controller;
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('searchProducts'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: context.appColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                elevation: 8,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 220, maxWidth: 360),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final product = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(product['name'] as String),
                        subtitle: Text(context.tr('availableQuantity',
                            {'quantity': product['quantity']})),
                        onTap: () => onSelected(product),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(context.tr('quantity')),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: '1.0',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _addSelectedItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.warning,
                foregroundColor: context.appColors.background,
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('addItem')),
            ),
          ],
        ),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              _FieldLabel(context.tr('selectedItems')),
              const Spacer(),
              Text(
                context.tr('itemCount', {'count': _items.length}),
                style:
                    TextStyle(color: context.appColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) {
            final line = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: context.appColors.surfaceHigh,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 17, color: context.appColors.warning),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      line.product['name'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '× ${line.quantity.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: context.appColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: context.tr('removeItem'),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _items.removeAt(entry.key)),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: context.appColors.danger),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 14),
        _FieldLabel(context.tr('notesOptional')),
        const SizedBox(height: 7),
        TextField(
          controller: _reasonController,
          maxLines: 2,
          decoration:
              InputDecoration(hintText: context.tr('materialNotesHint')),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(context.tr('cancel')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.warning,
                foregroundColor: context.appColors.background,
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submitting
                  ? context.tr('submitting')
                  : context.tr('submitItems', {'count': _items.length})),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.appColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
}
