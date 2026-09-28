import 'package:file_picker/file_picker.dart';
import 'expense_model.dart';

class MealItemDraft {
  final int? id;
  final DateTime date;
  final String type, merchant, note;
  final int amountMinor;
  final PlatformFile? receipt;
  const MealItemDraft({
    this.id,
    required this.date,
    required this.type,
    required this.amountMinor,
    this.merchant = '',
    this.note = '',
    this.receipt,
  });
}

class MealDraft {
  final int companyId;
  final DateTime date;
  final String note;
  final List<MealItemDraft> items;
  const MealDraft({
    required this.companyId,
    required this.date,
    this.note = '',
    required this.items,
  });
  static String dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int get total => items.fold(0, (sum, item) => sum + item.amountMinor);
  String? validate() {
    if (companyId <= 0) return 'Select a company.';
    if (note.length > 5000) {
      return 'Employee note must not exceed 5,000 characters.';
    }
    if (items.isEmpty || items.length > 20) {
      return 'Add between 1 and 20 meal receipts.';
    }
    if (total > 999999999999999) return 'The claim total is too large.';
    for (final item in items) {
      if (!['Breakfast', 'Lunch', 'Dinner', 'Meal'].contains(item.type)) {
        return 'Select a valid meal type.';
      }
      if (item.amountMinor < 0 || item.amountMinor > 99999999999999) {
        return 'Enter a valid claim amount.';
      }
      if (item.merchant.length > 255 || item.note.length > 5000) {
        return 'The merchant or receipt note is too long.';
      }
      final file = item.receipt;
      if (file == null && item.id == null) {
        return 'Every meal item requires a receipt photo.';
      }
      if (file != null &&
          (file.size <= 0 ||
              file.size > 5 * 1024 * 1024 ||
              !['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase()) ||
              (file.bytes == null && file.path == null))) {
        return 'Select a JPG or PNG receipt photo of up to 5 MB.';
      }
    }
    return null;
  }
}

class MealModel {
  final Map<String, dynamic> data;
  MealModel.fromJson(this.data);
  int get id => (data['id'] as num).toInt();
  int get companyId => (data['company_id'] as num).toInt();
  String text(String key) => data[key]?.toString() ?? '';
  bool get canEdit => data['can_edit'] == true;
  List<String> get actions => List<String>.from(data['actions'] ?? []);
  bool get canApprove => actions.any((a) => a != 'cancel');
  List<Map<String, dynamic>> get items => (data['items'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

typedef MealCompany = ExpenseCompany;
