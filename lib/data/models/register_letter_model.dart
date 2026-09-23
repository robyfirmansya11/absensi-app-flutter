import 'package:file_picker/file_picker.dart';

class RegisterLetterDraft {
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
  final String number;
  final String recipient;
  final String description;
  final PlatformFile? attachment;
  final bool hasExistingAttachment;
  const RegisterLetterDraft({
    required this.companyId,
    required this.date,
    required this.number,
    required this.recipient,
    this.description = '',
    this.attachment,
    this.hasExistingAttachment = false,
  });

  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (number.trim().isEmpty || number.length > 255) {
      return 'Enter a letter number of up to 255 characters.';
    }
    if (recipient.trim().isEmpty || recipient.length > 255) {
      return 'Enter a recipient of up to 255 characters.';
    }
    if (description.length > 5000) {
      return 'The description must not exceed 5,000 characters.';
    }
    final file = attachment;
    if (file == null) {
      return hasExistingAttachment ? null : 'An attachment is required.';
    }
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
      'tanggal_surat':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'no_surat': number.trim(),
      'ditujukan': recipient.trim(),
      'keterangan': description.trim(),
    };
  }
}

class RegisterLetterModel {
  final int id;
  final Map<String, dynamic> data;
  RegisterLetterModel.fromJson(this.data) : id = (data['id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
  int get companyId => (data['company_id'] as num).toInt();
  bool get canEdit => data['can_edit'] == true;
  bool get canDelete => data['can_delete'] == true;
  bool get hasAttachment => data['has_attachment'] == true;
}

class RegisterLetterCompany {
  final int id;
  final String name;
  const RegisterLetterCompany({required this.id, required this.name});
  factory RegisterLetterCompany.fromJson(Map<String, dynamic> json) =>
      RegisterLetterCompany(
        id: (json['id'] as num).toInt(),
        name: json['nama'] as String,
      );
}
