import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/loan_model.dart';
import '../../providers/loan_provider.dart';

class LoanFormScreen extends ConsumerStatefulWidget {
  final LoanModel? record;
  const LoanFormScreen({super.key, this.record});
  @override
  ConsumerState<LoanFormScreen> createState() => _LoanFormState();
}

class _LoanFormState extends ConsumerState<LoanFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _transfer = TextEditingController();
  final _description = TextEditingController();
  DateTime _date = DateTime.now();
  int? _company;
  PlatformFile? _file;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _amount.text = r.text('jumlah_dana');
      _transfer.text = r.text('informasi_transfer');
      _description.text = r.text('keterangan');
      _company = r.companyId;
      _date = DateTime.tryParse(r.text('tanggal')) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _transfer.dispose();
    _description.dispose();
    super.dispose();
  }

  void _error(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: LoanDraft.extensions,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size <= 0 || file.size > LoanDraft.maxFileBytes) {
        _error('The attachment must not be empty or exceed 10 MB.');
        return;
      }
      setState(() => _file = file);
    } catch (_) {
      if (mounted) _error('Unable to select the attachment. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_picking ||
        ref.read(loanProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    final draft = LoanDraft(
      companyId: _company!,
      date: _date,
      amountMinor: LoanDraft.parseMoney(_amount.text) ?? 0,
      transferInfo: _transfer.text,
      description: _description.text,
      attachment: _file,
    );
    final error = draft.validate();
    if (error != null) {
      _error(error);
      return;
    }
    final success = await ref
        .read(loanProvider.notifier)
        .save(draft, id: widget.record?.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _error(
        ref.read(loanProvider).submitError ??
            'Unable to save the loan request.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(loanProvider).isSubmitting;
    final companies = ref.watch(loanCompaniesProvider);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.record == null ? 'New Loan Note' : 'Edit Loan Note',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                companies.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Column(
                    children: [
                      Text('Unable to load companies: $e'),
                      TextButton(
                        onPressed: () => ref.invalidate(loanCompaniesProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                  data: (items) => DropdownButtonFormField<int>(
                    initialValue: items.any((c) => c.id == _company)
                        ? _company
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
                    items: items
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (id) => setState(() => _company = id),
                    validator: (id) =>
                        id == null || !items.any((c) => c.id == id)
                        ? 'Select a company.'
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2200),
                          );
                          if (mounted && date != null) {
                            setState(() => _date = date);
                          }
                        },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Request Date: ${DateFormat('dd MMM yyyy').format(_date)}',
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('amount'),
                  controller: _amount,
                  enabled: !busy,
                  maxLength: 15,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Requested Amount',
                    prefixText: 'Rp ',
                    helperText:
                        'No thousands separators; for example, 250000 or 250000.50.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = LoanDraft.parseMoney(value ?? '');
                    return amount == null || amount <= 0
                        ? 'Enter an amount greater than zero, with up to 2 decimal places.'
                        : null;
                  },
                ),
                const Text(
                  'The amount in words is generated automatically when saved.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('transfer'),
                  controller: _transfer,
                  enabled: !busy,
                  maxLength: 5000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Transfer Information (Optional)',
                    hintText: 'Bank name, account number, and account holder',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: !busy,
                  maxLength: 5000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (widget.record?.hasAttachment == true)
                  const Text(
                    'The existing attachment will be retained unless you select a replacement.',
                  ),
                OutlinedButton.icon(
                  onPressed: busy || _picking ? null : _pick,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _picking
                        ? 'Selecting file...'
                        : 'Select Attachment (Optional)',
                  ),
                ),
                const Text(
                  'PDF, JPG, PNG, Word, or Excel. Maximum file size: 10 MB.',
                ),
                if (_file != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_file!.name),
                    trailing: IconButton(
                      tooltip: 'Clear selected file',
                      onPressed: busy
                          ? null
                          : () => setState(() => _file = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      busy ||
                          _picking ||
                          companies.isLoading ||
                          !companies.hasValue
                      ? null
                      : _save,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(busy ? 'Saving...' : 'Save Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
