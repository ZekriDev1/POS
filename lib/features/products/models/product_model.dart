class ProductModel {
  final String id;
  final String? barcode;
  final String name;
  final String? description;
  final String? image;
  final String? categoryId;
  final double? costPrice;
  final double sellingPrice;
  final int quantity;

  const ProductModel({
    required this.id,
    this.barcode,
    required this.name,
    this.description,
    this.image,
    this.categoryId,
    this.costPrice,
    required this.sellingPrice,
    this.quantity = 0,
  });
}
