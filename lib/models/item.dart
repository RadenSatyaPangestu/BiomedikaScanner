class Item {
  final int? id;
  final String? assetNumber;
  final String serialNumber;
  final String itemName;
  final String? brand;
  final String? type;
  final int? roomId;
  final String? roomName;
  final int quantity;
  final String? source;
  final int? acquisitionYear;
  final DateTime? placedInServiceAt;
  final String? fiscalGroup;
  final String? status;
  final String? condition;
  final String? imagePath;
  final String? imageUrl; // Tambahan untuk URL absolut gambar

  // Keep category for backward compatibility with List Screen if needed,
  // or map 'type' to it.
  final String category;

  Item({
    this.id,
    this.assetNumber,
    required this.serialNumber,
    required this.itemName,
    this.brand,
    this.type,
    this.roomId,
    this.roomName,
    this.quantity = 1,
    this.source,
    this.acquisitionYear,
    this.placedInServiceAt,
    this.fiscalGroup,
    this.status,
    this.condition,
    this.imagePath,
    this.imageUrl,
    this.category = '',
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()),
      assetNumber: json['asset_number'],
      itemName: json['name'] ?? json['item_name'] ?? '',
      serialNumber: json['serial_number'] ?? json['sn'] ?? '',
      brand: json['brand'] ?? json['merk'],
      type: json['type'],

      // Relations
      roomId: json['room_id'] is int
          ? json['room_id']
          : int.tryParse(json['room_id'].toString() ?? ''),
      // Handle both nested room object or flat room_name
      roomName: json['room'] != null
          ? (json['room']['name'] ?? json['room_name'])
          : json['room_name'],

      quantity: (json['quantity'] is int)
          ? json['quantity']
          : int.tryParse(json['quantity'].toString()) ?? 1,

      source: json['source'],

      acquisitionYear: (json['acquisition_year'] is int)
          ? json['acquisition_year']
          : int.tryParse(json['acquisition_year'].toString()),

      placedInServiceAt: json['placed_in_service_at'] != null
          ? DateTime.tryParse(json['placed_in_service_at'])
          : null,

      fiscalGroup: json['fiscal_group'],
      status: json['status'],
      condition: json['condition'],
      imagePath: json['image_path'],
      imageUrl: json['image_url'],

      // Fallback for category from type if category is missing in JSON
      category: json['category'] ?? json['type'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset_number': assetNumber,
      'serial_number': serialNumber,
      'name': itemName,
      'brand': brand,
      'type': type,
      'room_id': roomId,
      'quantity': quantity,
      'source': source,
      'acquisition_year': acquisitionYear,
      'placed_in_service_at': placedInServiceAt
          ?.toIso8601String()
          .split('T')
          .first,
      'fiscal_group': fiscalGroup,
      'status': status,
      'condition': condition,
    };
  }
}
