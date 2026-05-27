class ReceiptData {
  final String itemName;
  final double? total;
  final DateTime? date;
  final String category;

  ReceiptData({
    required this.itemName,
    this.total,
    this.date,
    required this.category,
  });
}
