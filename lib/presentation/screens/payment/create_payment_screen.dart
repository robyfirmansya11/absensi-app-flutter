import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';

class CreatePaymentScreen extends ConsumerStatefulWidget {
  const CreatePaymentScreen({super.key});
  @override
  ConsumerState<CreatePaymentScreen> createState() =>
      _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends ConsumerState<CreatePaymentScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final name in [
      'invoice',
      'customer',
      'amount',
      'pph',
      'admin',
      'stage',
      'count',
      'description',
      'transfer',
    ])
      name: TextEditingController(),
  };
  int? _company;
  DateTime _billingDate = DateTime.now();
  DateTime _dueDate = DateTime.now();
  PlatformFile? _attachment;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _fields['pph']!.text = '0';
    _fields['admin']!.text = '0';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String name) => _fields[name]!.text.trim();
  int _money(String name) => PaymentDraft.parseMoney(_text(name)) ?? 0;
  String _rupiah(num value) => NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  Future<void> _pickDate(bool due) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: due ? _dueDate : _billingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: due ? 'Due Date' : 'Invoice Date',
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (due) {
        _dueDate = selected;
      } else {
        _billingDate = selected;
        if (_dueDate.isBefore(selected)) _dueDate = selected;
      }
    });
  }

  Future<void> _pickAttachment() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: PaymentDraft.extensions,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size <= 0 || file.size > PaymentDraft.maxFileBytes) {
        _error('Select a nonempty attachment of up to 10 MB.');
        return;
      }
      setState(() => _attachment = file);
    } catch (_) {
      if (mounted) _error('Unable to select the file. Please try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

  Future<void> _submit() async {
    if (_picking ||
        ref.read(paymentProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    if (_attachment == null) {
      _error('An attachment is required.');
      return;
    }
    final draft = PaymentDraft(
      companyId: _company!,
      invoice: _text('invoice'),
      customer: _text('customer'),
      billingDate: _billingDate,
      dueDate: _dueDate,
      amountMinor: _money('amount'),
      withholdingMinor: _money('pph'),
      adminMinor: _money('admin'),
      stage: int.tryParse(_text('stage')),
      attachmentCount: int.tryParse(_text('count')),
      description: _text('description'),
      transferInfo: _text('transfer'),
      attachment: _attachment!,
    );
    final error = draft.validate();
    if (error != null) {
      _error(error);
      return;
    }
    final success = await ref.read(paymentProvider.notifier).create(draft);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _error(
        ref.read(paymentProvider).submitError ??
            'Unable to submit the request.',
      );
    }
  }

  Widget _field(
    String name,
    String label,
    bool busy, {
    bool required = false,
    bool money = false,
    bool integer = false,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey(name),
        controller: _fields[name],
        enabled: !busy,
        maxLines: lines,
        maxLength: lines > 1 ? 5000 : (money || integer ? 16 : 255),
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : integer
            ? TextInputType.number
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixText: money ? 'Rp ' : null,
          helperText: money
              ? 'No thousands separators; for example, 25000 or 25000.50.'
              : null,
        ),
        onChanged: money ? (_) => setState(() {}) : null,
        validator: (value) {
          final text = value?.trim() ?? '';
          if (required && text.isEmpty) return '$label is required.';
          if (text.isEmpty) return null;
          if (money) {
            final minor = PaymentDraft.parseMoney(text);
            if (minor == null ||
                minor > 99999999999900 ||
                (name == 'amount' && minor <= 0)) {
              return 'Enter a valid amount with up to 2 decimal places.';
            }
          }
          if (integer) {
            final number = int.tryParse(text);
            if (number == null || number < 0 || number > 9999) {
              return 'Enter a whole number between 0 and 9,999.';
            }
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(paymentProvider).isSubmitting;
    final companies = ref.watch(paymentCompaniesProvider);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Payment Application'),
          foregroundColor: const Color(0xFF1B4F8A),
        ),
        backgroundColor: const Color(0xFFF5F6FA),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Payment Application Letter',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                companies.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Column(
                    children: [
                      Text('Unable to load companies: $e'),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(paymentCompaniesProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                  data: (items) => DropdownButtonFormField<int>(
                    initialValue: _company,
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
                _field('invoice', 'Invoice Number', busy, required: true),
                _field('customer', 'Recipient Company', busy, required: true),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Invoice Date: ${DateFormat('dd MMM yyyy').format(_billingDate)}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pickDate(true),
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Due Date: ${DateFormat('dd MMM yyyy').format(_dueDate)}',
                  ),
                ),
                const SizedBox(height: 20),
                _field('amount', 'Amount', busy, required: true, money: true),
                _field(
                  'pph',
                  'Withholding Tax (PPh)',
                  busy,
                  required: true,
                  money: true,
                ),
                _field(
                  'admin',
                  'Administration Fee',
                  busy,
                  required: true,
                  money: true,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VAT (11%): ${_rupiah(PaymentDraft.vatFor(_money('amount')))}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total tagihan: ${_rupiah(PaymentDraft.totalFor(_money('amount'), _money('pph'), _money('admin')))}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  'stage',
                  'Payment Stage (Optional)',
                  busy,
                  integer: true,
                ),
                _field(
                  'count',
                  'Attachment Count (Optional)',
                  busy,
                  integer: true,
                ),
                _field('description', 'Description (Optional)', busy, lines: 3),
                _field(
                  'transfer',
                  'Transfer Information (Optional)',
                  busy,
                  lines: 3,
                ),
                OutlinedButton.icon(
                  onPressed: busy || _picking ? null : _pickAttachment,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    _picking
                        ? 'Selecting file...'
                        : 'Select Required Attachment',
                  ),
                ),
                const Text(
                  'PDF, JPG, PNG, Word, or Excel. Maximum file size: 10 MB.',
                  style: TextStyle(fontSize: 12),
                ),
                if (_attachment != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_attachment!.name),
                    subtitle: Text(
                      '${(_attachment!.size / 1024).toStringAsFixed(0)} KB',
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove attachment',
                      onPressed: busy
                          ? null
                          : () => setState(() => _attachment = null),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      busy ||
                          _picking ||
                          !companies.hasValue ||
                          companies.isLoading
                      ? null
                      : _submit,
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
