import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/late_permit_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/late_permit_provider.dart';

class CreateLatePermitScreen extends ConsumerStatefulWidget {
  const CreateLatePermitScreen({super.key});
  @override
  ConsumerState<CreateLatePermitScreen> createState() =>
      _CreateLatePermitScreenState();
}

class _CreateLatePermitScreenState
    extends ConsumerState<CreateLatePermitScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay? _arrival;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _arrivalText => _arrival == null
      ? 'Select Arrival Time'
      : '${_arrival!.hour.toString().padLeft(2, '0')}:${_arrival!.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Late Arrival Date',
    );
    if (mounted && date != null) setState(() => _date = date);
  }

  Future<void> _pickArrival() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _arrival ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (mounted && time != null) setState(() => _arrival = time);
  }

  Future<void> _submit() async {
    if (ref.read(latePermitProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    if (ref.read(authProvider).user?.isSuperuser == true) return;
    final draft = LatePermitDraft(
      date: _date,
      arrivalTime: _arrivalText,
      reason: _reason.text,
    );
    final error = draft.validate();
    if (error != null) {
      _showError(error);
      return;
    }
    final success = await ref.read(latePermitProvider.notifier).create(draft);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _showError(
        ref.read(latePermitProvider).submitError ??
            'Unable to submit the request.',
      );
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(latePermitProvider).isSubmitting;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('New Late Arrival Request'),
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
                  'Enter the date, arrival time, and reason for your late arrival.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(_date)}',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : _pickArrival,
                  icon: const Icon(Icons.access_time),
                  label: Text('Arrival Time: $_arrivalText'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _reason,
                  enabled: !busy,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Late Arrival',
                    hintText: 'Explain the reason for your late arrival',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Provide a reason for your late arrival.'
                      : null,
                ),
                const SizedBox(height: 20),
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
