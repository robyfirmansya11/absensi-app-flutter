import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/overtime_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/overtime_provider.dart';

class CreateOvertimeScreen extends ConsumerStatefulWidget {
  const CreateOvertimeScreen({super.key});
  @override
  ConsumerState<CreateOvertimeScreen> createState() =>
      _CreateOvertimeScreenState();
}

class _CreateOvertimeScreenState extends ConsumerState<CreateOvertimeScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _meal = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime _month = DateTime.now();
  final Map<String, TimeOfDay?> _times = {
    'Work Start Time': null,
    'Work End Time': null,
    'Overtime Start Time': null,
    'Overtime End Time': null,
  };

  @override
  void dispose() {
    _description.dispose();
    _meal.dispose();
    super.dispose();
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  double? get _hours {
    final start = _times['Overtime Start Time'];
    final end = _times['Overtime End Time'];
    if (start == null || end == null) return null;
    return ((end.hour * 60 + end.minute) - (start.hour * 60 + start.minute)) /
        60;
  }

  Future<void> _pickDate(bool month) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: month ? _month : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: month ? 'Select Request Month' : 'Select Overtime Date',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (month) {
        _month = selected;
      } else {
        _date = selected;
        _month = selected;
      }
    });
  }

  Future<void> _pickTime(String label) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[label] ?? const TimeOfDay(hour: 17, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _times[label] = selected);
  }

  Future<void> _submit() async {
    if (ref.read(overtimeProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    if (ref.read(authProvider).user?.isSuperuser == true) return;
    if (_times.values.any((v) => v == null)) {
      _showError('Complete all work and overtime times.');
      return;
    }
    final draft = OvertimeDraft(
      month: _month,
      date: _date,
      workStart: _time(_times['Work Start Time']!),
      workEnd: _time(_times['Work End Time']!),
      overtimeStart: _time(_times['Overtime Start Time']!),
      overtimeEnd: _time(_times['Overtime End Time']!),
      mealAllowance: _meal.text.trim().isEmpty
          ? null
          : double.parse(_meal.text.trim().replaceAll(',', '.')),
      description: _description.text,
    );
    final error = draft.validate();
    if (error != null) {
      _showError(error);
      return;
    }
    final success = await ref.read(overtimeProvider.notifier).create(draft);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(
        ref.read(overtimeProvider).submitError ??
            'Unable to submit the request.',
      );
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(overtimeProvider).isSubmitting;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('New Overtime Request'),
          foregroundColor: const Color(0xFF1B4F8A),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your working hours and describe the overtime work performed.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Overtime Date: ${DateFormat('dd MMM yyyy').format(_date)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pickDate(true),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    'Request Month: ${DateFormat('MM/yyyy').format(_month)}',
                  ),
                ),
                const SizedBox(height: 12),
                for (final label in _times.keys) ...[
                  OutlinedButton(
                    onPressed: busy ? null : () => _pickTime(label),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$label: ${_times[label] == null ? 'Select Time' : _time(_times[label]!)}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 8),
                Text(
                  'Total Overtime: ${_hours == null || _hours! <= 0 ? '—' : '${_hours!.toStringAsFixed(2)} hours'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'The end time must be after the start time on the same day.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _meal,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Meal Allowance (Optional)',
                    prefixText: 'Rp ',
                    hintText: 'Example: 25000',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final amount = double.tryParse(
                      value.trim().replaceAll(',', '.'),
                    );
                    return amount == null ||
                            !amount.isFinite ||
                            amount < 0 ||
                            amount > 9999999999.99
                        ? 'Enter a valid amount without thousands separators.'
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _description,
                  enabled: !busy,
                  maxLines: 4,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Work Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Provide a work description.'
                      : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : _submit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(busy ? 'Submitting...' : 'Submit Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
