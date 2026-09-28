import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/meal_model.dart';
import '../../../data/models/expense_model.dart';
import '../../providers/meal_provider.dart';

class MealFormScreen extends ConsumerStatefulWidget {
  final MealModel? record;
  const MealFormScreen({super.key, this.record});
  @override
  ConsumerState<MealFormScreen> createState() => _MealFormState();
}

class _ItemFields {
  int? id;
  DateTime date = DateTime.now();
  String type = 'Meal';
  final merchant = TextEditingController(),
      amount = TextEditingController(text: '0'),
      note = TextEditingController();
  PlatformFile? receipt;
  _ItemFields([Map<String, dynamic>? data]) {
    if (data != null) {
      id = (data['id'] as num).toInt();
      date = DateTime.parse(data['meal_date']);
      type = data['meal_type'];
      merchant.text = data['merchant'] ?? '';
      amount.text = '${data['amount']}';
      note.text = data['note'] ?? '';
    }
  }
  void dispose() {
    merchant.dispose();
    amount.dispose();
    note.dispose();
  }
}

class _MealFormState extends ConsumerState<MealFormScreen> {
  final _form = GlobalKey<FormState>(), _note = TextEditingController();
  final _items = <_ItemFields>[];
  int? _company;
  DateTime _date = DateTime.now();
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      _company = record.companyId;
      _date = DateTime.parse(record.text('claim_date'));
      _note.text = record.text('employee_note');
      _items.addAll(record.items.map(_ItemFields.new));
    } else {
      _items.add(_ItemFields());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(_ItemFields item) async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size <= 0 || file.size > 5 * 1024 * 1024) {
        _message('Select a receipt photo of up to 5 MB.');
        return;
      }
      setState(() => item.receipt = file);
    } catch (_) {
      if (mounted) {
        _message('Unable to open the photo picker. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _datePicker(
    DateTime date,
    void Function(DateTime) change,
  ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (mounted && selected != null) setState(() => change(selected));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final draft = MealDraft(
      companyId: _company ?? 0,
      date: _date,
      note: _note.text,
      items: _items
          .map(
            (item) => MealItemDraft(
              id: item.id,
              date: item.date,
              type: item.type,
              merchant: item.merchant.text,
              note: item.note.text,
              amountMinor: ExpenseDraft.parseMoney(item.amount.text) ?? -1,
              receipt: item.receipt,
            ),
          )
          .toList(),
    );
    final error = draft.validate();
    if (error != null) {
      _message(error);
      return;
    }
    final success = await ref
        .read(mealProvider.notifier)
        .save(draft, id: widget.record?.id);
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      _message(
        ref.read(mealProvider).submitError ?? 'Unable to save the claim.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(mealCompaniesProvider);
    final busy = ref.watch(mealProvider).isSubmitting || _picking;
    final total = _items.fold<int>(
      0,
      (sum, item) => sum + (ExpenseDraft.parseMoney(item.amount.text) ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record == null ? 'New Meal Claim' : 'Edit Meal Claim',
        ),
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              companies.when(
                data: (rows) => DropdownButtonFormField<int>(
                  initialValue: _company,
                  decoration: const InputDecoration(labelText: 'Company'),
                  isExpanded: true,
                  items: rows
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _company = v),
                  validator: (v) => v == null ? 'Select a company.' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => TextButton(
                  onPressed: () => ref.invalidate(mealCompaniesProvider),
                  child: const Text('Unable to load companies. Retry'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Submission Date'),
                subtitle: Text(MealDraft.dateText(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _datePicker(_date, (d) => _date = d),
              ),
              TextFormField(
                controller: _note,
                maxLength: 5000,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Employee Note (Optional)',
                ),
              ),
              const Text(
                'Meal Receipts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var i = 0; i < _items.length; i++) _itemCard(_items[i], i),
              if (_items.length < 20)
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemFields())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Receipt'),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Total Claim Amount: IDR ${(total / 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton(
                onPressed: busy ? null : _save,
                child: Text(
                  busy
                      ? 'Saving…'
                      : widget.record == null
                      ? 'Submit Claim'
                      : 'Save and Submit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(_ItemFields item, int index) => Card(
    key: ObjectKey(item),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receipt ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_items.length > 1)
                IconButton(
                  tooltip: 'Remove Receipt',
                  onPressed: () => setState(() {
                    _items.remove(item);
                    item.dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => _pick(item),
            icon: const Icon(Icons.photo),
            label: Text(
              item.receipt?.name ??
                  (item.id == null
                      ? 'Select Receipt Photo'
                      : 'Replace Receipt Photo (Optional)'),
            ),
          ),
          if (item.id != null && item.receipt == null)
            const Text('Existing receipt photo will be retained.'),
          const Text(
            'JPG or PNG, up to 5 MB per receipt.',
            style: TextStyle(fontSize: 12),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Meal Date'),
            subtitle: Text(MealDraft.dateText(item.date)),
            onTap: () => _datePicker(item.date, (d) => item.date = d),
          ),
          DropdownButtonFormField<String>(
            initialValue: item.type,
            decoration: const InputDecoration(labelText: 'Meal Type'),
            items: ['Breakfast', 'Lunch', 'Dinner', 'Meal']
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t == 'Meal' ? 'Other Meal' : t),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => item.type = v!),
          ),
          TextFormField(
            controller: item.merchant,
            maxLength: 255,
            decoration: const InputDecoration(
              labelText: 'Restaurant / Merchant (Optional)',
            ),
          ),
          TextFormField(
            controller: item.amount,
            decoration: const InputDecoration(
              labelText: 'Claim Amount (IDR)',
              helperText: 'Use a decimal point and no thousands separators.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            validator: (v) => ExpenseDraft.parseMoney(v ?? '') == null
                ? 'Enter a valid amount.'
                : null,
          ),
          TextFormField(
            controller: item.note,
            maxLength: 5000,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Receipt Note (Optional)',
            ),
          ),
        ],
      ),
    ),
  );
}
