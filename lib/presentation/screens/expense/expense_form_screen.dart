import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/expense_provider.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final ExpenseModel? record;
  const ExpenseFormScreen({super.key, this.record});
  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormState();
}

class _ExpenseFields {
  final description = TextEditingController();
  final amount = TextEditingController(text: '0');
  _ExpenseFields([Map<String, dynamic>? data]) {
    if (data != null) {
      description.text = data['keterangan']?.toString() ?? '';
      amount.text = data['jumlah']?.toString() ?? '0';
    }
  }
  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _ExpenseFormState extends ConsumerState<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  final _entries = <_ExpenseFields>[];
  final _count = TextEditingController(text: '0');
  final _transfer = TextEditingController();

  DateTime _date = DateTime.now();
  int? _company;
  PlatformFile? _file;
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _entries.addAll(r.details.map(_ExpenseFields.new));
      _count.text = r.text('jumlah_lampiran');
      _transfer.text = r.text('informasi_transfer');
      _company = r.companyId;
      _date = DateTime.tryParse(r.text('tanggal')) ?? DateTime.now();
    }
    if (_entries.isEmpty) _entries.add(_ExpenseFields());
  }

  @override
  void dispose() {
    _count.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    _transfer.dispose();
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
        allowedExtensions: ExpenseDraft.extensions,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size <= 0 || file.size > ExpenseDraft.maxFileBytes) {
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
        ref.read(expenseProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    final draft = ExpenseDraft(
      companyId: _company!,
      date: _date,
      details: _entries
          .map(
            (e) => ExpenseEntry(
              description: e.description.text,
              amountMinor: ExpenseDraft.parseMoney(e.amount.text) ?? -1,
            ),
          )
          .toList(),
      attachmentCount: int.tryParse(_count.text) ?? -1,
      transferInfo: _transfer.text,
      attachment: _file,
    );
    final error = draft.validate();
    if (error != null) {
      _error(error);
      return;
    }
    final success = await ref
        .read(expenseProvider.notifier)
        .save(draft, id: widget.record?.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _error(
        ref.read(expenseProvider).submitError ??
            'Unable to save the expense reimbursement.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(expenseProvider).isSubmitting;
    final companies = ref.watch(expenseCompaniesProvider);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.record == null
                ? 'New Expense Reimbursement Note'
                : 'Edit Expense Reimbursement Note',
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
                        onPressed: () =>
                            ref.invalidate(expenseCompaniesProvider),
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
                for (var i = 0; i < _entries.length; i++)
                  Card(
                    key: ObjectKey(_entries[i]),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Expense Item ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_entries.length > 1)
                                IconButton(
                                  tooltip: 'Remove expense item ${i + 1}',
                                  onPressed: busy
                                      ? null
                                      : () {
                                          final removed = _entries[i];
                                          setState(
                                            () => _entries.remove(removed),
                                          );
                                          WidgetsBinding.instance
                                              .addPostFrameCallback((_) {
                                                removed.dispose();
                                              });
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                          TextFormField(
                            controller: _entries[i].description,
                            enabled: !busy,
                            maxLength: 5000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Expense Description',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter an expense description.'
                                : null,
                          ),
                          TextFormField(
                            key: ValueKey('amount-$i'),
                            controller: _entries[i].amount,
                            enabled: !busy,
                            maxLength: 15,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixText: 'Rp ',
                              helperText:
                                  'No thousands separators; up to 2 decimal places.',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              final value = ExpenseDraft.parseMoney(v ?? '');
                              return value == null
                                  ? 'Enter a valid amount.'
                                  : null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || _entries.length >= 5
                      ? null
                      : () => setState(() => _entries.add(_ExpenseFields())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense Item (Maximum 5)'),
                ),
                Text(
                  'Total: ${NumberFormat.currency(locale: "en_US", symbol: "Rp ", decimalDigits: 2).format(_entries.fold<int>(0, (sum, e) => sum + (ExpenseDraft.parseMoney(e.amount.text) ?? 0)) / 100)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
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
                  controller: _count,
                  enabled: !busy,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Attachment Count',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final count = int.tryParse(v ?? '');
                    return count == null || count < 0 || count > 9999
                        ? 'Enter an attachment count between 0 and 9,999.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
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
