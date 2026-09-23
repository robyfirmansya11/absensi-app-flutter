import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/register_letter_model.dart';
import '../../providers/register_letter_provider.dart';
import 'register_letter_form_screen.dart';

class RegisterLetterScreen extends ConsumerStatefulWidget {
  const RegisterLetterScreen({super.key});
  @override
  ConsumerState<RegisterLetterScreen> createState() =>
      _RegisterLetterScreenState();
}

class _RegisterLetterScreenState extends ConsumerState<RegisterLetterScreen> {
  String _search = '';
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(registerLetterProvider.notifier).load();
    });
  }

  Future<void> _edit([RegisterLetterModel? record]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterLetterFormScreen(record: record),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Letter saved successfully.')));
    await ref.read(registerLetterProvider.notifier).load();
  }

  Future<void> _delete(RegisterLetterModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this letter?'),
        content: Text(
          'Letter ${record.text('no_surat')} will be removed from the active register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final success = await ref
        .read(registerLetterProvider.notifier)
        .delete(record.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Letter deleted.'
              : ref.read(registerLetterProvider).submitError ??
                    'Unable to delete the letter.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerLetterProvider);
    final records = state.records
        .where(
          (r) => [
            'no_surat',
            'ditujukan',
            'company_name',
            'created_by',
            'keterangan',
          ].any((key) => r.text(key).toLowerCase().contains(_search)),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Register Letter'),
        actions: [
          IconButton(
            tooltip: 'Register a letter',
            onPressed: state.isSubmitting ? null : () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => ref.read(registerLetterProvider.notifier).load(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const Text('Registered Letters — All Users'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText:
                          'Search by letter number, recipient, or company',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 16),
                  if (state.loadError != null) ...[
                    Text(state.loadError!),
                    TextButton(
                      onPressed: () =>
                          ref.read(registerLetterProvider.notifier).load(),
                      child: const Text('Try Again'),
                    ),
                  ] else if (records.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _search.isEmpty
                            ? 'No registered letters yet.'
                            : 'No matching letters found.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final record in records)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              record.text('no_surat'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text('Recipient: ${record.text('ditujukan')}'),
                            Text('Date: ${record.text('tanggal_surat')}'),
                            Text('Company: ${record.text('company_name')}'),
                            Text('Created By: ${record.text('created_by')}'),
                            if (record.text('keterangan').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(record.text('keterangan')),
                              ),
                            if (record.hasAttachment)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('Attachment saved'),
                              ),
                            Wrap(
                              spacing: 12,
                              children: [
                                if (record.canEdit)
                                  TextButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _edit(record),
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Edit'),
                                  ),
                                if (record.canDelete)
                                  TextButton.icon(
                                    onPressed: state.isSubmitting
                                        ? null
                                        : () => _delete(record),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Delete'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
