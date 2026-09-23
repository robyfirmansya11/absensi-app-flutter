class TravelEntry {
  static const costs = [
    'amount_transportasi',
    'amount_tunjangan',
    'amount_hotel',
    'misc',
    'amount_other',
  ];
  final Map<String, dynamic> data;
  TravelEntry(this.data);
  static int? money(String value) {
    final text = value.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(text)) return null;
    final p = text.split('.');
    return int.parse(p[0]) * 100 +
        (p.length == 1 ? 0 : int.parse(p[1].padRight(2, '0')));
  }

  static String decimal(int value) =>
      '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  int cost(String key) => money(data[key]?.toString() ?? '0') ?? 0;
  int get subtotal =>
      cost('amount_transportasi') +
      cost('amount_tunjangan') * (int.tryParse('${data['jumlah_hari']}') ?? 0) +
      cost('amount_hotel') * (int.tryParse('${data['lama_hotel']}') ?? 0) +
      cost('misc') +
      cost('amount_other');
  String? validate() {
    final departure = DateTime.tryParse('${data['tanggal_berangkat']}');
    final arrival = DateTime.tryParse('${data['tanggal_tujuan']}');
    if (departure == null || arrival == null || arrival.isBefore(departure)) {
      return 'The arrival date cannot be earlier than the departure date.';
    }
    for (final key in ['tempat_berangkat', 'tempat_tujuan']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isEmpty || value.length > 255) {
        return 'Enter a departure location and destination, each up to 255 characters.';
      }
    }
    for (final key in ['waktu_berangkat', 'waktu_tujuan']) {
      final time = data[key]?.toString() ?? '';
      if (time.isNotEmpty &&
          !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
        return 'Enter the time in HH:mm format.';
      }
    }
    final start = data['waktu_berangkat']?.toString() ?? '';
    final end = data['waktu_tujuan']?.toString() ?? '';
    if (departure == arrival &&
        start.isNotEmpty &&
        end.isNotEmpty &&
        end.compareTo(start) < 0) {
      return 'Arrival cannot be earlier than departure.';
    }
    for (final key in ['jumlah_hari', 'lama_hotel']) {
      final value = int.tryParse('${data[key]}');
      if (value == null ||
          value < (key == 'jumlah_hari' ? 1 : 0) ||
          value > 3650) {
        return 'Travel days must be between 1 and 3,650; hotel nights must be between 0 and 3,650.';
      }
    }
    for (final key in costs) {
      if (money('${data[key]}') == null) {
        return 'Each cost must be between 0 and 999,999,999.99, with up to 2 decimal places.';
      }
    }
    if (subtotal > 99999999999999) {
      return 'The subtotal exceeds the maximum allowed amount.';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    for (final key in [
      'tanggal_berangkat',
      'tanggal_tujuan',
      'tempat_berangkat',
      'tempat_tujuan',
    ])
      key: data[key].toString().trim(),
    for (final key in ['waktu_berangkat', 'waktu_tujuan'])
      key: (data[key]?.toString().isNotEmpty ?? false) ? data[key] : null,
    for (final key in ['jumlah_hari', 'lama_hotel'])
      key: int.parse('${data[key]}'),
    for (final key in costs) key: decimal(cost(key)),
  };
}

class TravelDraft {
  final int companyId;
  final String description;
  final String notes;
  final int attachmentCount;
  final List<TravelEntry> details;
  const TravelDraft({
    required this.companyId,
    required this.description,
    required this.details,
    this.notes = '',
    this.attachmentCount = 0,
  });
  int get total => details.fold(0, (sum, item) => sum + item.subtotal);
  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (description.trim().isEmpty || description.length > 5000) {
      return 'Enter a description of up to 5,000 characters.';
    }
    if (notes.length > 5000) return 'Notes must not exceed 5,000 characters.';
    if (attachmentCount < 0 || attachmentCount > 9999) {
      return 'Attachment count must be between 0 and 9,999.';
    }
    if (details.isEmpty || details.length > 5) {
      return 'Enter between 1 and 5 travel entries.';
    }
    for (var i = 0; i < details.length; i++) {
      final error = details[i].validate();
      if (error != null) return 'Travel Entry ${i + 1}: $error';
    }
    if (total > 99999999999999) {
      return 'The total exceeds the maximum allowed amount.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    return {
      'company_id': companyId,
      'keterangan': description.trim(),
      'catatan': notes.trim(),
      'jumlah_lampiran': attachmentCount,
      'details': details.map((e) => e.toJson()).toList(),
    };
  }
}

class TravelModel {
  final int id;
  final Map<String, dynamic> data;
  TravelModel.fromJson(this.data) : id = (data['id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
  int get companyId => (data['company_id'] as num).toInt();
  List<Map<String, dynamic>> get details => (data['details'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  bool get canEdit => data['can_edit'] == true;
  bool get canCancel => data['can_cancel'] == true;
  bool get canApprove => data['can_approve'] == true;
  String get statusLabel => switch (text('status')) {
    'Pending Approval' =>
      data['approval_level'] == 1
          ? 'Awaiting Supervisor Approval'
          : 'Awaiting Finance Manager Approval',
    'Approved' => 'Approved',
    'Rejected' => 'Rejected',
    'Cancelled' => 'Cancelled',
    _ => text('status'),
  };
}

class TravelCompany {
  final int id;
  final String name;
  const TravelCompany({required this.id, required this.name});
  factory TravelCompany.fromJson(Map<String, dynamic> json) => TravelCompany(
    id: (json['id'] as num).toInt(),
    name: json['nama'] as String,
  );
}
