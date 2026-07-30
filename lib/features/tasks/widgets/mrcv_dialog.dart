import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/workshop_task.dart';
import '../data/task_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_locale.dart';

class MrcvDialog extends StatefulWidget {
  final WorkshopTask task;

  const MrcvDialog({super.key, required this.task});

  @override
  State<MrcvDialog> createState() => _MrcvDialogState();
}

class _MrcvDialogState extends State<MrcvDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();

  bool _isLoadingContext = true;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _warehouses = [];
  Map<String, dynamic>? _selectedWarehouse;
  Map<String, dynamic>? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final repo = sl<TaskRepository>();
      final contextData = await repo.getMrcvContext(widget.task.jobId!);
      if (mounted) {
        setState(() {
          _warehouses =
              (contextData['warehouses'] as List).cast<Map<String, dynamic>>();
          if (_warehouses.isNotEmpty) {
            _selectedWarehouse = _warehouses.first;
          }
          _isLoadingContext = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContext = false);
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitMRCV() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWarehouse == null || _selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a warehouse and a product',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = sl<TaskRepository>();
      await repo.createMrcvRequest(
        jobId: widget.task.jobId!,
        warehouseId: _selectedWarehouse!['id'] as int,
        productId: _selectedProduct!['id'] as int,
        quantity: double.tryParse(_qtyController.text.trim()) ?? 1.0,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material Request (MRCV) submitted successfully!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit MRCV: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: AppColors.warning, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('requestMaterial'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          widget.task.jobName ?? widget.task.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Warehouse Dropdown
              Text(
                'Warehouse',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              if (_isLoadingContext)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (_warehouses.isEmpty)
                Text('No warehouses found',
                    style: GoogleFonts.inter(color: AppColors.danger))
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _selectedWarehouse,
                  dropdownColor: AppColors.surfaceHigh,
                  style: GoogleFonts.inter(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  items: _warehouses.map((w) {
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: w,
                      child: Text(w['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedWarehouse = val;
                      _selectedProduct = null; // reset product
                    });
                  },
                ),
              const SizedBox(height: 14),

              // Product Autocomplete
              Text(
                'Product',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 6),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (option) => option['name'] as String,
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text == '' ||
                      _selectedWarehouse == null) {
                    return const Iterable<Map<String, dynamic>>.empty();
                  }
                  final repo = sl<TaskRepository>();
                  return await repo.searchWarehouseProducts(
                    _selectedWarehouse!['lot_stock_id'] as int,
                    textEditingValue.text,
                  );
                },
                onSelected: (Map<String, dynamic> selection) {
                  setState(() {
                    _selectedProduct = selection;
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ),
                    validator: (val) => _selectedProduct == null
                        ? 'Please select a product'
                        : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              title: Text(option['name'] as String,
                                  style: GoogleFonts.inter(
                                      color: Colors.white, fontSize: 14)),
                              subtitle: Text('Qty: ${option['quantity']}',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 12)),
                              onTap: () {
                                onSelected(option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Quantity
              Text(
                'Requested Quantity',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _qtyController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '1.0',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter quantity';
                  }
                  if (double.tryParse(val.trim()) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Reason / Notes
              Text(
                'Notes / Reason (Optional)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Replacement needed for maintenance',
                  hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(
                      context.tr('cancel'),
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitMRCV,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit MRCV',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: AppColors.background,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
