import 'package:flutter/foundation.dart';

/// Statut du chauffeur
enum DriverStatus { active, inactive, onLeave, suspended }

/// Extension pour le statut du chauffeur
extension DriverStatusExtension on DriverStatus {
  String get display {
    switch (this) {
      case DriverStatus.active:
        return 'Actif';
      case DriverStatus.inactive:
        return 'Inactif';
      case DriverStatus.onLeave:
        return 'En congé';
      case DriverStatus.suspended:
        return 'Suspendu';
    }
  }
}

/// Catégorie de licence de conduite
enum LicenseCategory { a, b, c, d, e }

/// Extension pour la catégorie de licence
extension LicenseCategoryExtension on LicenseCategory {
  String get display {
    switch (this) {
      case LicenseCategory.a:
        return 'A';
      case LicenseCategory.b:
        return 'B';
      case LicenseCategory.c:
        return 'C';
      case LicenseCategory.d:
        return 'D';
      case LicenseCategory.e:
        return 'E';
    }
  }
}

/// Document du chauffeur
@immutable
class DriverDocument {
  final String id;
  final String name;
  final String type;
  final String url;
  final DateTime uploadDate;
  final DateTime? expiryDate;

  const DriverDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.uploadDate,
    this.expiryDate,
  });

  DriverDocument copyWith({
    String? id,
    String? name,
    String? type,
    String? url,
    DateTime? uploadDate,
    DateTime? expiryDate,
  }) {
    return DriverDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      uploadDate: uploadDate ?? this.uploadDate,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'url': url,
      'uploadDate': uploadDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      uploadDate: DateTime.parse(json['uploadDate'] as String),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
    );
  }
}

/// Voyage historique du chauffeur
@immutable
class DriverTrip {
  final String id;
  final DateTime date;
  final String destination;
  final double mileage;
  final double revenue;
  final String status;
  final String? vehiclePlate;

  const DriverTrip({
    required this.id,
    required this.date,
    required this.destination,
    required this.mileage,
    required this.revenue,
    required this.status,
    this.vehiclePlate,
  });

  DriverTrip copyWith({
    String? id,
    DateTime? date,
    String? destination,
    double? mileage,
    double? revenue,
    String? status,
    String? vehiclePlate,
  }) {
    return DriverTrip(
      id: id ?? this.id,
      date: date ?? this.date,
      destination: destination ?? this.destination,
      mileage: mileage ?? this.mileage,
      revenue: revenue ?? this.revenue,
      status: status ?? this.status,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'destination': destination,
      'mileage': mileage,
      'revenue': revenue,
      'status': status,
      'vehiclePlate': vehiclePlate,
    };
  }

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      destination: json['destination'] as String,
      mileage: (json['mileage'] as num).toDouble(),
      revenue: (json['revenue'] as num).toDouble(),
      status: json['status'] as String,
      vehiclePlate: json['vehiclePlate'] as String?,
    );
  }
}

/// Camion assigné au chauffeur
@immutable
class AssignedVehicle {
  final String id;
  final String plate;
  final String brand;
  final String model;
  final int year;
  final double mileage;
  final String status;

  const AssignedVehicle({
    required this.id,
    required this.plate,
    required this.brand,
    required this.model,
    required this.year,
    required this.mileage,
    required this.status,
  });

  AssignedVehicle copyWith({
    String? id,
    String? plate,
    String? brand,
    String? model,
    int? year,
    double? mileage,
    String? status,
  }) {
    return AssignedVehicle(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      status: status ?? this.status,
    );
  }

  String get displayName => '$brand $model ($plate)';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'status': status,
    };
  }

  factory AssignedVehicle.fromJson(Map<String, dynamic> json) {
    return AssignedVehicle(
      id: json['id'] as String,
      plate: json['plate'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      mileage: (json['mileage'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}

/// Model représentant un chauffeur
@immutable
class Driver {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime birthDate;
  final String address;
  final String city;
  final String postalCode;
  final String country;
  final String? avatarUrl;

  // Informations professionnelles
  final DateTime hireDate;
  final LicenseCategory licenseCategory;
  final String licenseNumber;
  final DateTime licenseExpiryDate;
  final double monthlySalary;
  final DriverStatus status;

  // Camion assigné
  final AssignedVehicle? assignedVehicle;

  // Documents
  final List<DriverDocument> documents;

  // Statistiques
  final int totalTrips;
  final int monthlyTrips;
  final int weeklyTrips;
  final double totalMileage;
  final double monthlyMileage;
  final double totalRevenue;
  final double monthlyRevenue;
  final double rating;
  final int ratingCount;

  // Historique des voyages
  final List<DriverTrip> tripHistory;

  // Métadonnées
  final DateTime createdAt;
  final DateTime updatedAt;

  const Driver({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.birthDate,
    required this.address,
    required this.city,
    required this.postalCode,
    required this.country,
    this.avatarUrl,
    required this.hireDate,
    required this.licenseCategory,
    required this.licenseNumber,
    required this.licenseExpiryDate,
    required this.monthlySalary,
    this.status = DriverStatus.active,
    this.assignedVehicle,
    this.documents = const [],
    this.totalTrips = 0,
    this.monthlyTrips = 0,
    this.weeklyTrips = 0,
    this.totalMileage = 0.0,
    this.monthlyMileage = 0.0,
    this.totalRevenue = 0.0,
    this.monthlyRevenue = 0.0,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.tripHistory = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Getters
  String get fullName => '$firstName $lastName';
  String get driverId {
    final idLen = id.length;
    final subLen = idLen < 6 ? idLen : 6;
    return 'DRV-${id.substring(0, subLen).toUpperCase()}';
  }

  String get initials {
    if (firstName.isEmpty || lastName.isEmpty) return '?';
    return '${firstName[0]}${lastName[0]}'.toUpperCase();
  }

  String get licenseCategoryDisplay {
    switch (licenseCategory) {
      case LicenseCategory.a:
        return 'A';
      case LicenseCategory.b:
        return 'B';
      case LicenseCategory.c:
        return 'C';
      case LicenseCategory.d:
        return 'D';
      case LicenseCategory.e:
        return 'E';
    }
  }

  String get statusDisplay {
    switch (status) {
      case DriverStatus.active:
        return 'Actif';
      case DriverStatus.inactive:
        return 'Inactif';
      case DriverStatus.onLeave:
        return 'En congé';
      case DriverStatus.suspended:
        return 'Suspendu';
    }
  }

  String get experience {
    final now = DateTime.now();
    final difference = now.difference(hireDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;

    if (years > 0 && months > 0) {
      return '$years ans ${months}mois';
    } else if (years > 0) {
      return '$years ans';
    } else if (months > 0) {
      return '$months mois';
    } else {
      return '< 1 mois';
    }
  }

  int get experienceYears {
    final now = DateTime.now();
    return now.difference(hireDate).inDays ~/ 365;
  }

  bool get isLicenseValid => licenseExpiryDate.isAfter(DateTime.now());

  Driver copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? birthDate,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? avatarUrl,
    DateTime? hireDate,
    LicenseCategory? licenseCategory,
    String? licenseNumber,
    DateTime? licenseExpiryDate,
    double? monthlySalary,
    DriverStatus? status,
    AssignedVehicle? assignedVehicle,
    List<DriverDocument>? documents,
    int? totalTrips,
    int? monthlyTrips,
    int? weeklyTrips,
    double? totalMileage,
    double? monthlyMileage,
    double? totalRevenue,
    double? monthlyRevenue,
    double? rating,
    int? ratingCount,
    List<DriverTrip>? tripHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hireDate: hireDate ?? this.hireDate,
      licenseCategory: licenseCategory ?? this.licenseCategory,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      status: status ?? this.status,
      assignedVehicle: assignedVehicle ?? this.assignedVehicle,
      documents: documents ?? this.documents,
      totalTrips: totalTrips ?? this.totalTrips,
      monthlyTrips: monthlyTrips ?? this.monthlyTrips,
      weeklyTrips: weeklyTrips ?? this.weeklyTrips,
      totalMileage: totalMileage ?? this.totalMileage,
      monthlyMileage: monthlyMileage ?? this.monthlyMileage,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      tripHistory: tripHistory ?? this.tripHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'birthDate': birthDate.toIso8601String(),
      'address': address,
      'city': city,
      'postalCode': postalCode,
      'country': country,
      'avatarUrl': avatarUrl,
      'hireDate': hireDate.toIso8601String(),
      'licenseCategory': licenseCategory.index,
      'licenseNumber': licenseNumber,
      'licenseExpiryDate': licenseExpiryDate.toIso8601String(),
      'monthlySalary': monthlySalary,
      'status': status.index,
      'assignedVehicle': assignedVehicle?.toJson(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'totalTrips': totalTrips,
      'monthlyTrips': monthlyTrips,
      'weeklyTrips': weeklyTrips,
      'totalMileage': totalMileage,
      'monthlyMileage': monthlyMileage,
      'totalRevenue': totalRevenue,
      'monthlyRevenue': monthlyRevenue,
      'rating': rating,
      'ratingCount': ratingCount,
      'tripHistory': tripHistory.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      birthDate: DateTime.parse(json['birthDate'] as String),
      address: json['address'] as String,
      city: json['city'] as String,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hireDate: DateTime.parse(json['hireDate'] as String),
      licenseCategory: LicenseCategory.values[json['licenseCategory'] as int],
      licenseNumber: json['licenseNumber'] as String,
      licenseExpiryDate: DateTime.parse(json['licenseExpiryDate'] as String),
      monthlySalary: (json['monthlySalary'] as num).toDouble(),
      status: DriverStatus.values[json['status'] as int],
      assignedVehicle: json['assignedVehicle'] != null
          ? AssignedVehicle.fromJson(
              json['assignedVehicle'] as Map<String, dynamic>,
            )
          : null,
      documents:
          (json['documents'] as List<dynamic>?)
              ?.map((d) => DriverDocument.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      totalTrips: json['totalTrips'] as int? ?? 0,
      monthlyTrips: json['monthlyTrips'] as int? ?? 0,
      weeklyTrips: json['weeklyTrips'] as int? ?? 0,
      totalMileage: (json['totalMileage'] as num?)?.toDouble() ?? 0.0,
      monthlyMileage: (json['monthlyMileage'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      tripHistory:
          (json['tripHistory'] as List<dynamic>?)
              ?.map((t) => DriverTrip.fromJson(t as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'Driver(id: $id, name: $fullName, email: $email, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Driver && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Filtres pour la liste des chauffeurs
class DriverFilters {
  final String searchQuery;
  final DriverStatus? status;
  final int? minExperience;
  final int? maxExperience;
  final double? minRating;
  final bool? hasVehicle;

  const DriverFilters({
    this.searchQuery = '',
    this.status,
    this.minExperience,
    this.maxExperience,
    this.minRating,
    this.hasVehicle,
  });

  DriverFilters copyWith({
    String? searchQuery,
    DriverStatus? status,
    int? minExperience,
    int? maxExperience,
    double? minRating,
    bool? hasVehicle,
  }) {
    return DriverFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      status: status ?? this.status,
      minExperience: minExperience ?? this.minExperience,
      maxExperience: maxExperience ?? this.maxExperience,
      minRating: minRating ?? this.minRating,
      hasVehicle: hasVehicle ?? this.hasVehicle,
    );
  }

  bool get isEmpty =>
      searchQuery.isEmpty &&
      status == null &&
      minExperience == null &&
      maxExperience == null &&
      minRating == null &&
      hasVehicle == null;
}
