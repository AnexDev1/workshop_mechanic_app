import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models/workshop_task.dart';
import '../data/task_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_locale.dart';

class OutsourceDialog extends StatefulWidget {
  final WorkshopTask task;
  const OutsourceDialog({super.key, required this.task});

  @override
  State<OutsourceDialog> createState() => _OutsourceDialogState();
}

class _OutsourceDialogState extends State<OutsourceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await sl<TaskRepository>().requestOutsource(
        taskId: widget.task.id,
        jobId: widget.task.jobId!,
        reason: _reasonCtrl.text.trim(),
        estimatedCost: double.tryParse(_costCtrl.text) ?? 0.0,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Outsource request submitted successfully'),
            backgroundColor: context.appColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.appColors.warning.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.open_in_new_rounded,
                        color: context.appColors.warning, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.tr('requestOutsource'),
                        style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: context.appColors.text)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(widget.task.description,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: context.appColors.textMuted)),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appColors.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: context.appColors.danger.withValues(alpha: .35)),
                  ),
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: context.appColors.danger)),
                ),
                const SizedBox(height: 12),
              ],
              // Reason
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(
                    color: context.appColors.text, fontSize: 13),
                decoration: _inputDecoration('Reason for Outsourcing *',
                    'Describe why this needs external work...'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Reason is required' : null,
              ),
              const SizedBox(height: 12),
              // Estimated Cost
              TextFormField(
                controller: _costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                    color: context.appColors.text, fontSize: 13),
                decoration:
                    _inputDecoration('Estimated Cost (ETB)', 'e.g. 5000.00'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        foregroundColor: context.appColors.textMuted,
                      ),
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                      child: Text(context.tr('cancel'),
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appColors.warning,
                        foregroundColor: context.appColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Submit',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
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

  InputDecoration _inputDecoration(String label, String hint) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            GoogleFonts.inter(color: context.appColors.textMuted, fontSize: 12),
        hintStyle: GoogleFonts.inter(
            color: context.appColors.textSubtle, fontSize: 12),
        filled: true,
        fillColor: context.appColors.surfaceHigh,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.appColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.appColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: context.appColors.warning, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
