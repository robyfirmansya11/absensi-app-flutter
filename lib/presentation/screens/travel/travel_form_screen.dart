import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/travel_model.dart';
import '../../providers/travel_provider.dart';

class TravelFormScreen extends ConsumerStatefulWidget {
  final TravelModel? record;
  const TravelFormScreen({super.key, this.record});
  @override
  ConsumerState<TravelFormScreen> createState() => _TravelFormState();
}

class _EntryFields {
  final fields = <String, TextEditingController>{};
  _EntryFields([Map<String, dynamic>? data]) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final entry in {
      'tanggal_berangkat': today,
      'tanggal_tujuan': today,
      'waktu_berangkat': '',
      'waktu_tujuan': '',
      'tempat_berangkat': '',
      'tempat_tujuan': '',
      'jumlah_hari': '1',
      'lama_hotel': '0',
      for (final key in TravelEntry.costs) key: '0',
    }.entries) {
      var value = data?[entry.key]?.toString() ?? entry.value;
      if (entry.key.startsWith('waktu_') && value.length >= 5) {
        value = value.substring(0, 5);
      }
      fields[entry.key] = TextEditingController(text: value);
    }
  }
  TravelEntry get value =>
      TravelEntry({for (final e in fields.entries) e.key: e.value.text.trim()});
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
  }
}

class _TravelFormState extends ConsumerState<TravelFormScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _count = TextEditingController(text: '0');
  final _entries = <_EntryFields>[];
  int? _company;
  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _company = r.companyId;
      _description.text = r.text('keterangan');
      _notes.text = r.text('catatan');
      _count.text = r.text('jumlah_lampiran');
      _entries.addAll(r.details.map(_EntryFields.new));
    }
    if (_entries.isEmpty) _entries.add(_EntryFields());
  }

  @override
  void dispose() {
    _description.dispose();
    _notes.dispose();
    _count.dispose();
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  String _money(int cents) => NumberFormat.currency(
    locale: 'en_US',
    symbol: 'Rp ',
    decimalDigits: 2,
  ).format(cents / 100);
  Future<void> _save() async {
    if (ref.read(travelProvider).isSubmitting ||
        !_form.currentState!.validate()) {
      return;
    }
    final draft = TravelDraft(
      companyId: _company!,
      description: _description.text,
      notes: _notes.text,
      attachmentCount: int.tryParse(_count.text) ?? -1,
      details: _entries.map((e) => e.value).toList(),
    );
    final error = draft.validate();
    if (error != null) {
      _error(error);
      return;
    }
    final ok = await ref
        .read(travelProvider.notifier)
        .save(draft, id: widget.record?.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _error(
        ref.read(travelProvider).submitError ?? 'Unable to save the request.',
      );
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  Widget _field(
    TextEditingController controller,
    String label,
    bool busy, {
    bool required = false,
    bool numeric = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      maxLines: lines,
      maxLength: lines > 1 ? 5000 : (numeric ? 15 : 255),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: numeric ? (_) => setState(() {}) : null,
      validator: (value) => required && (value?.trim().isEmpty ?? true)
          ? '$label is required.'
          : null,
    ),
  );
  Widget _date(_EntryFields entry, String key, String label, bool busy) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text('$label: ${entry.fields[key]!.text}'),
          onPressed: busy
              ? null
              : () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(entry.fields[key]!.text) ??
                        DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2200),
                  );
                  if (mounted && selected != null) {
                    setState(
                      () => entry.fields[key]!.text = DateFormat(
                        'yyyy-MM-dd',
                      ).format(selected),
                    );
                  }
                },
        ),
      );
  Widget _time(_EntryFields entry, String key, String label, bool busy) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.schedule),
          label: Text(
            '$label: ${entry.fields[key]!.text.isEmpty ? "Optional" : entry.fields[key]!.text}',
          ),
          onPressed: busy
              ? null
              : () async {
                  final parts = entry.fields[key]!.text.split(':');
                  final time = await showTimePicker(
                    context: context,
                    initialTime: parts.length == 2
                        ? TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          )
                        : TimeOfDay.now(),
                  );
                  if (mounted && time != null) {
                    setState(
                      () => entry.fields[key]!.text =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    );
                  }
                },
        ),
      ),
      if (entry.fields[key]!.text.isNotEmpty)
        IconButton(
          tooltip: 'Clear time',
          onPressed: busy
              ? null
              : () => setState(() => entry.fields[key]!.clear()),
          icon: const Icon(Icons.close),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(travelProvider).isSubmitting;
    final companies = ref.watch(travelCompaniesProvider);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.record == null
                ? 'New Travel Reimbursement'
                : 'Edit Travel Reimbursement',
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
                            ref.invalidate(travelCompaniesProvider),
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
                        : (v) => setState(() => _company = v),
                    validator: (v) => v == null || !items.any((c) => c.id == v)
                        ? 'Select a company.'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _field(
                  _description,
                  'Description',
                  busy,
                  required: true,
                  lines: 3,
                ),
                _field(_count, 'Attachment Count', busy, numeric: true),
                const Text('Enter the number of supporting documents.'),
                const SizedBox(height: 16),
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
                                  'Travel Entry ${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (_entries.length > 1)
                                IconButton(
                                  tooltip: 'Remove travel entry ${i + 1}',
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
                          _date(
                            _entries[i],
                            'tanggal_berangkat',
                            'Departure Date',
                            busy,
                          ),
                          _time(
                            _entries[i],
                            'waktu_berangkat',
                            'Departure Time',
                            busy,
                          ),
                          _field(
                            _entries[i].fields['tempat_berangkat']!,
                            'Departure Location',
                            busy,
                            required: true,
                          ),
                          _date(
                            _entries[i],
                            'tanggal_tujuan',
                            'Arrival Date',
                            busy,
                          ),
                          _time(
                            _entries[i],
                            'waktu_tujuan',
                            'Arrival Time',
                            busy,
                          ),
                          _field(
                            _entries[i].fields['tempat_tujuan']!,
                            'Destination',
                            busy,
                            required: true,
                          ),
                          _field(
                            _entries[i].fields['jumlah_hari']!,
                            'Number of Days',
                            busy,
                            numeric: true,
                          ),
                          _field(
                            _entries[i].fields['lama_hotel']!,
                            'Hotel Nights',
                            busy,
                            numeric: true,
                          ),
                          const Text(
                            'Amounts are in IDR. Do not use thousands separators. Up to 2 decimal places.',
                          ),
                          const SizedBox(height: 12),
                          for (final e in {
                            'amount_transportasi': 'Transportation',
                            'amount_tunjangan': 'Daily Allowance',
                            'amount_hotel': 'Nightly Hotel Rate',
                            'misc': 'Miscellaneous Expenses',
                            'amount_other': 'Other Expenses',
                          }.entries)
                            _field(
                              _entries[i].fields[e.key]!,
                              e.value,
                              busy,
                              numeric: true,
                            ),
                          Text(
                            'Subtotal: ${_money(_entries[i].value.subtotal)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy || _entries.length >= 5
                      ? null
                      : () => setState(() => _entries.add(_EntryFields())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Travel Entry (Maximum 5)'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total: ${_money(_entries.fold<int>(0, (sum, e) => sum + e.value.subtotal))}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'The amount in words is generated automatically when saved.',
                ),
                const SizedBox(height: 16),
                _field(_notes, 'Notes (Optional)', busy, lines: 3),
                FilledButton.icon(
                  onPressed: busy || companies.isLoading || !companies.hasValue
                      ? null
                      : _save,
                  icon: const Icon(Icons.save),
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
