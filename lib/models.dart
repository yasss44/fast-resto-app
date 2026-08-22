// lib/models.dart
import 'dart:convert';

enum DietaryPreference {
  vegan('Végétalien'),
  vegetarian('Végétarien'),
  glutenFree('Sans Gluten'),
  halal('Halal'),
  keto('Céto'),
  dairyFree('Sans Lactose');

  final String label;
  const DietaryPreference(this.label);

  static DietaryPreference fromString(String value) {
    return DietaryPreference.values.firstWhere(
      (e) => e.label.toLowerCase() == value.toLowerCase() || e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DietaryPreference.vegan,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String image;
  final String category;
  final List<DietaryPreference> dietaryTags;
  final double rating;
  final bool available;
  final List<MenuItemSupplement> supplements;

  MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.category,
    required this.dietaryTags,
    required this.rating,
    this.available = true,
    this.supplements = const [],
  });

  MenuItem copyWith({
    String? name,
    String? description,
    double? price,
    String? image,
    String? category,
    List<DietaryPreference>? dietaryTags,
    bool? available,
  }) =>
      MenuItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        image: image ?? this.image,
        category: category ?? this.category,
        dietaryTags: dietaryTags ?? this.dietaryTags,
        rating: rating,
        available: available ?? this.available,
        supplements: supplements,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'image': image,
        'category': category,
        'dietaryTags': dietaryTags.map((t) => t.label).toList(),
        'rating': rating,
        'available': available,
      };

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        image: json['image'] as String,
        category: json['category'] as String,
        dietaryTags: (json['dietaryTags'] as List<dynamic>?)
                ?.map((e) => DietaryPreference.fromString(e as String))
                .toList() ??
            [],
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        available: json['available'] as bool? ?? true,
      );

  /// Parse from backend API JSON format
  /// Handles dietaryTags as [{"option": "HALAL"}] and camelCase fields
  factory MenuItem.fromApiJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        image: json['image'] as String? ?? '',
        category: json['category'] as String,
        dietaryTags: _parseDietaryTags(json['dietaryTags']),
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        available: json['isAvailable'] as bool? ?? json['available'] as bool? ?? true,
        supplements: (json['supplements'] as List<dynamic>?)
            ?.map((s) => MenuItemSupplement.fromJson(s as Map<String, dynamic>))
            .toList() ?? [],
      );

  static List<DietaryPreference> _parseDietaryTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) {
      return tags.map((e) {
        if (e is String) return DietaryPreference.fromString(e);
        if (e is Map<String, dynamic>) {
          return DietaryPreference.fromString(e['option'] as String? ?? '');
        }
        return DietaryPreference.vegan;
      }).toList();
    }
    return [];
  }
}

class MenuItemSupplement {
  final String id;
  final String name;
  final double price;

  const MenuItemSupplement({
    required this.id,
    required this.name,
    required this.price,
  });

  factory MenuItemSupplement.fromJson(Map<String, dynamic> json) =>
      MenuItemSupplement(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
}

class Review {
  final String id;
  final String userName;
  final String userEmail;
  final double rating;
  final String comment;
  final String date;

  Review({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userName': userName,
        'userEmail': userEmail,
        'rating': rating,
        'comment': comment,
        'date': date,
      };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        userName: json['userName'] as String,
        userEmail: json['userEmail'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String,
        date: json['date'] as String,
      );

  /// Parse from backend API JSON format
  /// Backend uses "createdAt" instead of "date", no "userEmail"
  factory Review.fromApiJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        userName: json['userName'] as String,
        userEmail: json['userEmail'] as String? ?? '',
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String? ?? '',
        date: (json['createdAt'] as String?) ?? (json['date'] as String? ?? ''),
      );
}

enum FulfillmentType {
  pickup('Retrait'),
  delivery('Livraison');

  final String label;
  const FulfillmentType(this.label);

  static FulfillmentType fromApi(String value) {
    return value.toUpperCase() == 'DELIVERY' ? FulfillmentType.delivery : FulfillmentType.pickup;
  }

  String get apiValue => this == FulfillmentType.delivery ? 'DELIVERY' : 'PICKUP';
}

class Restaurant {
  final String id;
  final String name;
  final String description;
  final String image;
  final String logo;
  final String category;
  final double rating;
  final int reviewsCount;
  final List<Review> reviews;
  final int pickupPrepTime; // in minutes
  final double distance; // in miles
  final List<DietaryPreference> dietaryOptions;
  final List<MenuItem> menu;
  final String address;
  final double latitude;
  final double longitude;
  final bool deliveryEnabled;
  final double deliveryFee;
  final double deliveryRadiusKm;

  Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.image,
    String? logo,
    required this.category,
    required this.rating,
    required this.reviewsCount,
    required this.reviews,
    required this.pickupPrepTime,
    required this.distance,
    required this.dietaryOptions,
    required this.menu,
    required this.address,
    this.latitude = 48.8566,
    this.longitude = 2.3522,
    this.deliveryEnabled = true,
    this.deliveryFee = 2.99,
    this.deliveryRadiusKm = 5.0,
  }) : logo = (logo != null && logo.isNotEmpty) ? logo : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'image': image,
        'logo': logo,
        'category': category,
        'rating': rating,
        'reviewsCount': reviewsCount,
        'reviews': reviews.map((r) => r.toJson()).toList(),
        'pickupPrepTime': pickupPrepTime,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
        'dietaryOptions': dietaryOptions.map((o) => o.label).toList(),
        'menu': menu.map((m) => m.toJson()).toList(),
        'address': address,
      };

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        image: json['image'] as String,
        logo: json['logo'] as String?,
        category: json['category'] as String,
        rating: (json['rating'] as num).toDouble(),
        reviewsCount: json['reviewsCount'] as int? ?? 0,
        reviews: (json['reviews'] as List<dynamic>?)
                ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pickupPrepTime: json['pickupPrepTime'] as int? ?? 15,
        distance: (json['distance'] as num?)?.toDouble() ?? 1.0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 48.8566,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 2.3522,
        dietaryOptions: (json['dietaryOptions'] as List<dynamic>?)
                ?.map((e) => DietaryPreference.fromString(e as String))
                .toList() ??
            [],
        menu: (json['menu'] as List<dynamic>?)
                ?.map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        address: json['address'] as String? ?? '',
        deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 2.99,
        deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
      );

  /// Parse from backend API JSON format
  /// Backend uses "menuItems" key, dietaryOptions as [{"option": "HALAL"}], no reviews in list
  factory Restaurant.fromApiJson(Map<String, dynamic> json) => Restaurant(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        image: json['image'] as String? ?? '',
        logo: json['logo'] as String?,
        category: json['category'] as String,
        rating: (json['rating'] as num).toDouble(),
        reviewsCount: json['reviewsCount'] as int? ?? 0,
        reviews: (json['reviews'] as List<dynamic>?)
                ?.map((e) => Review.fromApiJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pickupPrepTime: json['pickupPrepTime'] as int? ?? 15,
        distance: (json['distance'] as num?)?.toDouble() ?? 1.0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 48.8566,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 2.3522,
        dietaryOptions: _parseDietaryOptions(json['dietaryOptions']),
        menu: (json['menuItems'] as List<dynamic>?)
                ?.map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
                .toList() ??
            (json['menu'] as List<dynamic>?)
                    ?.map((e) => MenuItem.fromApiJson(e as Map<String, dynamic>))
                    .toList() ??
            [],
        address: json['address'] as String? ?? '',
        deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 2.99,
        deliveryRadiusKm: (json['deliveryRadiusKm'] as num?)?.toDouble() ?? 5.0,
      );

  static List<DietaryPreference> _parseDietaryOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) {
      return options.map((e) {
        if (e is String) return DietaryPreference.fromString(e);
        if (e is Map<String, dynamic>) {
          return DietaryPreference.fromString(e['option'] as String? ?? '');
        }
        return DietaryPreference.vegan;
      }).toList();
    }
    return [];
  }
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  final List<String> selectedOptions;
  String allergyNotes;
  CartItem({
    required this.menuItem,
    required this.quantity,
    this.selectedOptions = const [],
    this.allergyNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'menuItem': menuItem.toJson(),
        'quantity': quantity,
        'selectedOptions': selectedOptions,
        'allergyNotes': allergyNotes,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        menuItem: MenuItem.fromJson(json['menuItem'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
        selectedOptions: (json['selectedOptions'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        allergyNotes: json['allergyNotes'] as String? ?? '',
      );

  /// Parse from backend API JSON format
  /// Backend selectedOptions is a JSON string "[]" not a List
  factory CartItem.fromApiJson(Map<String, dynamic> json, {MenuItem? menuItem}) =>
      CartItem(
        menuItem: menuItem ??
            MenuItem.fromApiJson(json['menuItem'] as Map<String, dynamic>? ?? {}),
        quantity: json['quantity'] as int? ?? 1,
        selectedOptions: _parseSelectedOptions(json['selectedOptions']),
        allergyNotes: json['allergyNotes'] as String? ?? '',
      );

  static List<String> _parseSelectedOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) return options.cast<String>();
    if (options is String) {
      try {
        final parsed = jsonDecode(options);
        if (parsed is List) return parsed.cast<String>();
      } catch (_) {}
    }
    return [];
  }
}

enum OrderStatus {
  placed('Commandé'),
  preparing('En préparation'),
  readyForPickup('Prêt pour retrait'),
  completed('Récupéré'),
  cancelled('Annulé');

  final String label;
  const OrderStatus(this.label);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.label.toLowerCase() == value.toLowerCase() || e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => OrderStatus.placed,
    );
  }

  /// Parse backend UPPER_SNAKE format (e.g. "READY_FOR_PICKUP")
  static OrderStatus fromApiJson(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => OrderStatus.placed,
    );
  }
}

class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final List<CartItem> items;
  final double subtotal;
  final double serviceFee; // flat €1.50
  final double total;
  OrderStatus status;
  final String createdAt;
  
  // Client side tracking
  int userWalkTimeMinutes; // Countdown of walk progress
  bool isReadyAtEntrance;
  bool userRatingSubmitted;

  // Resto side tracking (Dashboard & Kitchen)
  String? prepStartedAt;
  int prepTimerSeconds;
  double gpsProgress; // 0 to 100
  bool isBilledAnyway; // For cancelled orders where prep already started
  bool isUrgent; // Green to Orange to Red
  final String? groupCode;
  final String? pickupToken;
  final FulfillmentType fulfillmentType;
  final String deliveryAddress;
  final double deliveryFee;
  final String? deliveryStatus;

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantImage,
    required this.items,
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.userWalkTimeMinutes,
    this.isReadyAtEntrance = false,
    this.userRatingSubmitted = false,
    this.prepStartedAt,
    this.prepTimerSeconds = 0,
    this.gpsProgress = 0.0,
    this.isBilledAnyway = false,
    this.isUrgent = false,
    this.groupCode,
    this.pickupToken,
    this.fulfillmentType = FulfillmentType.pickup,
    this.deliveryAddress = '',
    this.deliveryFee = 0,
    this.deliveryStatus,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantImage': restaurantImage,
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'serviceFee': serviceFee,
        'total': total,
        'status': status.name,
        'createdAt': createdAt,
        'userWalkTimeMinutes': userWalkTimeMinutes,
        'isReadyAtEntrance': isReadyAtEntrance,
        'userRatingSubmitted': userRatingSubmitted,
        'prepStartedAt': prepStartedAt,
        'prepTimerSeconds': prepTimerSeconds,
        'gpsProgress': gpsProgress,
        'isBilledAnyway': isBilledAnyway,
        'isUrgent': isUrgent,
        'groupCode': groupCode,
        'pickupToken': pickupToken,
        'fulfillmentType': fulfillmentType.name,
        'deliveryAddress': deliveryAddress,
        'deliveryFee': deliveryFee,
        'deliveryStatus': deliveryStatus,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        restaurantId: json['restaurantId'] as String,
        restaurantName: json['restaurantName'] as String,
        restaurantImage: json['restaurantImage'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        serviceFee: (json['serviceFee'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        status: OrderStatus.fromString(json['status'] as String),
        createdAt: json['createdAt'] as String,
        userWalkTimeMinutes: json['userWalkTimeMinutes'] as int,
        isReadyAtEntrance: json['isReadyAtEntrance'] as bool? ?? false,
        userRatingSubmitted: json['userRatingSubmitted'] as bool? ?? false,
        prepStartedAt: json['prepStartedAt'] as String?,
        prepTimerSeconds: json['prepTimerSeconds'] as int? ?? 0,
        gpsProgress: (json['gpsProgress'] as num?)?.toDouble() ?? 0.0,
        isBilledAnyway: json['isBilledAnyway'] as bool? ?? false,
        isUrgent: json['isUrgent'] as bool? ?? false,
        groupCode: json['groupCode'] as String?,
        pickupToken: json['pickupToken'] as String?,
        fulfillmentType: FulfillmentType.fromApi(json['fulfillmentType'] as String? ?? 'PICKUP'),
        deliveryAddress: json['deliveryAddress'] as String? ?? '',
        deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
        deliveryStatus: (json['delivery'] as Map<String, dynamic>?)?['status'] as String?,
      );

  /// Parse from backend API JSON format
  /// Maps userWalkTimeMin → userWalkTimeMinutes, nested restaurant object,
  /// UPPER_SNAKE status, JSON-string selectedOptions
  factory Order.fromApiJson(Map<String, dynamic> json) {
    final restaurantData = json['restaurant'] as Map<String, dynamic>?;
    final itemsData = (json['items'] as List<dynamic>?)
            ?.map((e) => CartItem.fromApiJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Order(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      restaurantName: restaurantData?['name'] as String? ??
          json['restaurantName'] as String? ??
          '',
      restaurantImage: restaurantData?['image'] as String? ??
          json['restaurantImage'] as String? ??
          '',
      items: itemsData,
      subtotal: (json['subtotal'] as num).toDouble(),
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 1.50,
      total: (json['total'] as num).toDouble(),
      status: OrderStatus.fromApiJson(json['status'] as String? ?? 'PLACED'),
      createdAt: json['createdAt'] as String,
      userWalkTimeMinutes: json['userWalkTimeMin'] as int? ??
          json['userWalkTimeMinutes'] as int? ??
          10,
      isReadyAtEntrance: json['isReadyAtEntrance'] as bool? ?? false,
      userRatingSubmitted: json['ratingSubmitted'] as bool? ?? false,
      prepStartedAt: json['prepStartedAt'] as String?,
      prepTimerSeconds: json['prepTimerSeconds'] as int? ?? 0,
      gpsProgress: (json['gpsProgress'] as num?)?.toDouble() ?? 0.0,
      isBilledAnyway: json['isBilledAnyway'] as bool? ?? false,
      isUrgent: json['isUrgent'] as bool? ?? false,
      groupCode: (json['groupOrder'] as Map<String, dynamic>?)?['code'] as String? ??
          json['groupCode'] as String?,
      pickupToken: json['pickupToken'] as String?,
      fulfillmentType: FulfillmentType.fromApi(json['fulfillmentType'] as String? ?? 'PICKUP'),
      deliveryAddress: json['deliveryAddress'] as String? ?? '',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
      deliveryStatus: (json['delivery'] as Map<String, dynamic>?)?['status'] as String?,
    );
  }

  bool get isDelivery => fulfillmentType == FulfillmentType.delivery;
}

class PushNotification {
  final String id;
  final String title;
  final String body;
  final String timestamp;
  bool isRead;
  final String type; // 'status' | 'info' | 'success' | 'rating'

  PushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp,
        'isRead': isRead,
        'type': type,
      };

  factory PushNotification.fromJson(Map<String, dynamic> json) => PushNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: json['timestamp'] as String,
        isRead: json['isRead'] as bool? ?? false,
        type: json['type'] as String,
      );

  /// Parse from backend API JSON format
  /// Backend uses "createdAt" instead of "timestamp", type is UPPERCASE
  factory PushNotification.fromApiJson(Map<String, dynamic> json) =>
      PushNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        timestamp: json['createdAt'] as String? ??
            json['timestamp'] as String? ??
            '',
        isRead: json['isRead'] as bool? ?? false,
        type: (json['type'] as String?)?.toLowerCase() ?? 'info',
      );
}

class RestaurantSettings {
  final String? id;
  final String managerFirstName;
  final String managerPhone;
  final String managerIban;
  final String name;
  final String description;
  final String image;
  final String cuisineType;
  final String category;
  final String city;
  final String address;
  final int normalPrepTime;
  final int rushPrepTime;
  final List<String> dietaryOptions;

  RestaurantSettings({
    this.id,
    required this.managerFirstName,
    required this.managerPhone,
    this.managerIban = '',
    required this.name,
    this.description = '',
    this.image = '',
    required this.cuisineType,
    this.category = '',
    required this.city,
    this.address = '',
    required this.normalPrepTime,
    required this.rushPrepTime,
    this.dietaryOptions = const [],
  });

  Map<String, dynamic> toJson() => {
        'managerFirstName': managerFirstName,
        'managerPhone': managerPhone,
        'managerIban': managerIban,
        'name': name,
        'description': description,
        'image': image,
        'cuisineType': cuisineType,
        'category': category,
        'city': city,
        'address': address,
        'normalPrepTime': normalPrepTime,
        'rushPrepTime': rushPrepTime,
        'dietaryOptions': dietaryOptions,
      };

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) => RestaurantSettings(
        id: json['id'] as String?,
        managerFirstName: json['managerFirstName'] as String? ?? '',
        managerPhone: json['managerPhone'] as String? ?? '',
        managerIban: json['managerIban'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        image: json['image'] as String? ?? '',
        cuisineType: json['cuisineType'] as String? ?? '',
        category: json['category'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        normalPrepTime: json['normalPrepTime'] as int? ?? 15,
        rushPrepTime: json['rushPrepTime'] as int? ?? 25,
        dietaryOptions: (json['dietaryOptions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  /// Build from backend API response (dietaryOptions as [{option: "HALAL"}])
  factory RestaurantSettings.fromApiJson(Map<String, dynamic> json) => RestaurantSettings(
        id: json['id'] as String?,
        managerFirstName: json['managerFirstName'] as String? ?? '',
        managerPhone: json['managerPhone'] as String? ?? '',
        managerIban: json['managerIban'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        image: json['image'] as String? ?? '',
        cuisineType: json['cuisineType'] as String? ?? '',
        category: json['category'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        normalPrepTime: json['normalPrepTime'] as int? ?? 15,
        rushPrepTime: json['rushPrepTime'] as int? ?? 25,
        dietaryOptions: _parseDietaryList(json['dietaryOptions']),
      );

  static List<String> _parseDietaryList(dynamic options) {
    if (options == null) return [];
    if (options is List) {
      return options.map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) return e['option'] as String? ?? '';
        return '';
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}
