import 'package:file_picker/file_picker.dart';

class PaymentDraft {
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
  final String invoice;
  final String customer;
  final DateTime billingDate;
  final DateTime dueDate;
  final int amountMinor;
  final int withholdingMinor;
  final int adminMinor;
  final int? stage;
  final int? attachmentCount;
  final String description;
  final String transferInfo;
  final PlatformFile attachment;

  const PaymentDraft({
    required this.companyId,
    required this.invoice,
    required this.customer,
    required this.billingDate,
    required this.dueDate,
    required this.amountMinor,
    this.withholdingMinor = 0,
    this.adminMinor = 0,
    this.stage,
    this.attachmentCount,
    this.description = '',
    this.transferInfo = '',
    required this.attachment,
  });

  // Integer cents avoid binary floating point differences in the preview.
  static int? parseMoney(String text) {
    final value = text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,12}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  static String moneyValue(int minor) =>
      '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  static int vatFor(int minor) => (minor * 11 + 5000) ~/ 10000;
  static int totalFor(int amount, int withholding, int admin) =>
      (amount + vatFor(amount) * 100 + admin - withholding + 50) ~/ 100;
  int get vat => vatFor(amountMinor);
  int get total => totalFor(amountMinor, withholdingMinor, adminMinor);

  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (invoice.trim().isEmpty || invoice.length > 255) {
      return 'Enter an invoice number of up to 255 characters.';
    }
    if (customer.trim().isEmpty || customer.length > 255) {
      return 'Enter a recipient name of up to 255 characters.';
    }
    if (DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(
      DateTime(billingDate.year, billingDate.month, billingDate.day),
    )) {
      return 'The due date cannot be earlier than the invoice date.';
    }
    if (amountMinor <= 0 ||
        amountMinor > 99999999999900 ||
        withholdingMinor < 0 ||
        withholdingMinor > 99999999999900 ||
        adminMinor < 0 ||
        adminMinor > 99999999999900) {
      return 'Enter a valid amount.';
    }
    if (amountMinor + vat * 100 + adminMinor - withholdingMinor <= 0 ||
        total <= 0 ||
        total > 999999999999) {
      return 'The total must be greater than zero and no more than IDR 999,999,999,999.';
    }
    if ((stage != null && (stage! < 0 || stage! > 9999)) ||
        (attachmentCount != null &&
            (attachmentCount! < 0 || attachmentCount! > 9999))) {
      return 'Payment stage and attachment count must be between 0 and 9,999.';
    }
    if (description.length > 5000 || transferInfo.length > 5000) {
      return 'Description and transfer information must each be no more than 5,000 characters.';
    }
    if (attachment.size <= 0 || attachment.size > maxFileBytes) {
      return 'An attachment is required and must not exceed 10 MB.';
    }
    if (!extensions.contains(attachment.extension?.toLowerCase())) {
      return 'This attachment format is not supported.';
    }
    if (attachment.path == null && attachment.bytes == null) {
      return 'Unable to read the attachment. Select the file again.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return {
      'company_id': companyId,
      'no_invoice': invoice.trim(),
      'customer': customer.trim(),
      'tanggal_penagihan': date(billingDate),
      'tanggal_jatuhtempo': date(dueDate),
      'jumlah': moneyValue(amountMinor),
      'pph': moneyValue(withholdingMinor),
      'admin': moneyValue(adminMinor),
      if (stage != null) 'pembayaran_tahap': stage,
      if (attachmentCount != null) 'jumlah_lampiran': attachmentCount,
      'keterangan': description.trim(),
      'informasi_transfer': transferInfo.trim(),
    };
  }
}

class PaymentModel {
  final int id;
  final Map<String, dynamic> data;
  PaymentModel.fromJson(this.data) : id = (data['id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
  double number(String key) => double.tryParse(text(key)) ?? 0;
  String get invoice => text('no_invoice');
  String get status => text('status');
  bool get canCancel => data['can_cancel'] == true;
  bool get canApprove => data['can_approve'] == true;
  String get statusLabel => switch (status) {
    'Pending Approval' =>
      data['approval_level'] == 1
          ? 'Awaiting Supervisor Approval'
          : 'Awaiting Finance Manager Approval',
    'Approved' => 'Approved',
    'Paid' => 'Paid',
    'Rejected' => 'Rejected',
    'Cancelled' => 'Cancelled',
    'Submitted' => 'Submitted',
    _ => status,
  };
}

class PaymentCompany {
  final int id;
  final String name;
  const PaymentCompany({required this.id, required this.name});
  factory PaymentCompany.fromJson(Map<String, dynamic> json) => PaymentCompany(
    id: (json['id'] as num).toInt(),
    name: json['nama'] as String,
  );
}
