import 'package:file_picker/file_picker.dart';

class LoanDraft {
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
  final int amountMinor;
  final String description;
  final String transferInfo;
  final PlatformFile? attachment;
  const LoanDraft({
    required this.companyId,
    required this.date,
    required this.amountMinor,
    this.description = '',
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

  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (amountMinor <= 0 || amountMinor > 99999999999999) {
      return 'The amount must be greater than zero and no more than IDR 999,999,999,999.99.';
    }
    if (description.length > 5000 || transferInfo.length > 5000) {
      return 'Description and transfer information must each be no more than 5,000 characters.';
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
      'jumlah_dana':
          '${amountMinor ~/ 100}.${(amountMinor % 100).toString().padLeft(2, '0')}',
      'keterangan': description.trim(),
      'informasi_transfer': transferInfo.trim(),
    };
  }
}

class LoanModel {
  final int id;
  final Map<String, dynamic> data;
  LoanModel.fromJson(this.data) : id = (data['id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
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

class LoanCompany {
  final int id;
  final String name;
  const LoanCompany({required this.id, required this.name});
  factory LoanCompany.fromJson(Map<String, dynamic> json) => LoanCompany(
    id: (json['id'] as num).toInt(),
    name: json['nama'] as String,
  );
}
