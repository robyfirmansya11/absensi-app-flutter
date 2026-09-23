import 'package:file_picker/file_picker.dart';

class ExpenseEntry {
  final String description;
  final int amountMinor;
  const ExpenseEntry({required this.description, required this.amountMinor});
  Map<String, dynamic> toJson() => {
    'keterangan': description.trim(),
    'jumlah':
        '${amountMinor ~/ 100}.${(amountMinor % 100).toString().padLeft(2, '0')}',
  };
}

class ExpenseDraft {
  static const maxFileBytes = 10 * 1024 * 1024;
  static const extensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'doc',
    'docx',
    'xls',
    'xlsx',
  ];
  final int companyId;
  final DateTime date;
  final List<ExpenseEntry> details;
  final int attachmentCount;
  final String transferInfo;
  final PlatformFile? attachment;
  const ExpenseDraft({
    required this.companyId,
    required this.date,
    required this.details,
    this.attachmentCount = 0,
    this.transferInfo = '',
    this.attachment,
  });
  static int? parseMoney(String text) {
    final value = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  int get total => details.fold(0, (sum, e) => sum + e.amountMinor);
  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (details.isEmpty || details.length > 5) {
      return 'Enter between 1 and 5 expense items.';
    }
    for (final e in details) {
      if (e.description.trim().isEmpty || e.description.length > 5000) {
        return 'Each expense requires a description of up to 5,000 characters.';
      }
      if (e.amountMinor < 0 || e.amountMinor > 99999999999999) {
        return 'Enter a valid expense amount.';
      }
    }
    if (total > 99999999999999) {
      return 'The total must not exceed IDR 999,999,999,999.99.';
    }
    if (attachmentCount < 0 || attachmentCount > 9999) {
      return 'Attachment count must be between 0 and 9,999.';
    }
    if (transferInfo.length > 5000) {
      return 'Transfer information must not exceed 5,000 characters.';
    }
    final file = attachment;
    if (file == null) return null;
    if (file.size <= 0 || file.size > maxFileBytes) {
      return 'The attachment must not be empty or exceed 10 MB.';
    }
    if (!extensions.contains(file.extension?.toLowerCase())) {
      return 'This attachment format is not supported.';
    }
    if (file.path == null && file.bytes == null) {
      return 'Unable to read the attachment. Select the file again.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    return {
      'company_id': companyId,
      'tanggal':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'details': details.map((e) => e.toJson()).toList(),
      'jumlah_lampiran': attachmentCount,
      'informasi_transfer': transferInfo.trim(),
    };
  }
}

class ExpenseModel {
  final int id;
  final Map<String, dynamic> data;
  ExpenseModel.fromJson(this.data) : id = (data['id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
  List<Map<String, dynamic>> get details => (data['details'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  int get companyId => (data['company_id'] as num).toInt();
  bool get canEdit => data['can_edit'] == true;
  bool get canCancel => data['can_cancel'] == true;
  bool get canApprove => data['can_approve'] == true;
  bool get hasAttachment => data['has_attachment'] == true;
  String get statusLabel => switch (text('status')) {
    'Pending Approval' =>
      data['approval_level'] == 1
          ? 'Awaiting Supervisor Approval'
          : 'Awaiting Finance Manager Approval',
    'Approved' => 'Approved',
    'Rejected' => 'Rejected',
    'Cancelled' => 'Cancelled',
    'Submitted' => 'Submitted',
    _ => text('status'),
  };
}

class ExpenseCompany {
  final int id;
  final String name;
  const ExpenseCompany({required this.id, required this.name});
  factory ExpenseCompany.fromJson(Map<String, dynamic> json) => ExpenseCompany(
    id: (json['id'] as num).toInt(),
    name: json['nama'] as String,
  );
}
