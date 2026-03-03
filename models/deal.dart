import 'package:cloud_firestore/cloud_firestore.dart';

class Deal {
  final String id;
  final String? title;
  final String? description;
  final String? pastedText;
  final String? imageUrl;
  final double? originalPrice;
  final double? discountPrice;
  final int? discountPercent;
  final String? storeName;
  final String? category;
  final DateTime expiryDate;
  final DateTime? createdAt;
  final int views;
  final int likes;
  final int shares;
  final List<String> likedBy;
  final List<String> sharedBy;
  final List<String> keywords;
  final double rankingScore;
  final bool isActive;
  final bool isHot;
  final bool isTrending;
  final bool isPinned;
  final bool isArchived;
  final bool isExpiringSoon;
  final String? externalUrl;
  final String? link;
  final String disclaimer;

  Deal({
    required this.id,
    this.title,
    this.description,
    this.pastedText,
    this.imageUrl,
    this.originalPrice,
    this.discountPrice,
    this.discountPercent,
    this.storeName,
    this.category,
    required this.expiryDate,
    this.createdAt,
    this.views = 0,
    this.likes = 0,
    this.shares = 0,
    this.likedBy = const [],
    this.sharedBy = const [],
    this.keywords = const [],
    this.rankingScore = 0.0,
    this.isActive = true,
    this.isHot = false,
    this.isTrending = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isExpiringSoon = false,
    this.externalUrl,
    this.link,
    this.disclaimer =
        'Prices and availability may change. We are not the seller of these products.',
  });

  double? get savings => (originalPrice != null && discountPrice != null)
      ? originalPrice! - discountPrice!
      : null;

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get hasValidPrice => originalPrice != null && discountPrice != null;
  bool get hasBasicInfo =>
      title != null || description != null || pastedText != null;
  bool get isVisible => isActive && !isArchived;

  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;
  int get hoursLeft => expiryDate.difference(DateTime.now()).inHours;

  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (pastedText != null && pastedText!.isNotEmpty) {
      return pastedText!.length > 50
          ? '${pastedText!.substring(0, 50)}...'
          : pastedText!;
    }
    if (description != null && description!.isNotEmpty) {
      return description!.length > 50
          ? '${description!.substring(0, 50)}...'
          : description!;
    }
    return 'Untitled Deal';
  }

  String get displayPrice {
    if (!hasValidPrice) return 'Price not available';
    return '\$${originalPrice!.toStringAsFixed(2)}';
  }

  String get displayDiscount {
    if (!hasValidPrice) return '';
    return 'Save \$${savings!.toStringAsFixed(2)} (${discountPercent}%)';
  }

  static double calculateRankingScore({
    required int discountPercent,
    required int views,
    required int daysLeft,
    bool isHot = false,
    bool isTrending = false,
    bool isPinned = false,
  }) {
    final discountScore = discountPercent * 0.5;
    final viewsScore = views * 0.00001;
    final urgencyScore = (30 - daysLeft).clamp(0, 30) * 0.2;

    final hotBonus = isHot ? 2.0 : 0;
    final trendingBonus = isTrending ? 1.5 : 0;
    final pinnedBonus = isPinned ? 3.0 : 0;

    return discountScore +
        viewsScore +
        urgencyScore +
        hotBonus +
        trendingBonus +
        pinnedBonus;
  }

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      pastedText: json['pastedText'],
      imageUrl: json['imageUrl'],
      originalPrice: json['originalPrice']?.toDouble(),
      discountPrice: json['discountPrice']?.toDouble(),
      discountPercent: json['discountPercent'],
      storeName: json['storeName'],
      category: json['category'],
      expiryDate: DateTime.parse(json['expiryDate']),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
                ? json['createdAt'].toDate()
                : DateTime.parse(json['createdAt']))
          : null,
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      shares: json['shares'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      sharedBy: List<String>.from(json['sharedBy'] ?? []),
      rankingScore: json['rankingScore']?.toDouble() ?? 0.0,
      isActive: json['isActive'] ?? true,
      isHot: json['isHot'] ?? false,
      isTrending: json['isTrending'] ?? false,
      isPinned: json['isPinned'] ?? false,
      isArchived: json['isArchived'] ?? false,
      isExpiringSoon: json['isExpiringSoon'] ?? false,
      externalUrl: json['externalUrl'],
      link: json['link'],
      disclaimer: json['disclaimer'] ?? 'Prices and availability may change.',
    );
  }

  factory Deal.fromFirestore(Map<String, dynamic> data, String documentId) {
    DateTime expiryDate;

    if (data['expiryDate'] != null) {
      if (data['expiryDate'] is Timestamp) {
        expiryDate = data['expiryDate'].toDate();
      } else if (data['expiryDate'] is String) {
        expiryDate = DateTime.parse(data['expiryDate']);
      } else {
        expiryDate = DateTime.now().add(const Duration(days: 30));
      }
    } else {
      expiryDate = DateTime.now().add(const Duration(days: 30));
    }

    DateTime? createdAt;
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        createdAt = data['createdAt'].toDate();
      } else if (data['createdAt'] is String) {
        createdAt = DateTime.parse(data['createdAt']);
      }
    }

    return Deal(
      id: documentId,
      title: data['title'],
      description: data['description'],
      pastedText: data['pastedText'],
      imageUrl: data['imageUrl'],
      originalPrice: data['originalPrice']?.toDouble(),
      discountPrice: (data['discountPrice'] ?? data['discountedPrice'])
          ?.toDouble(),
      discountPercent: data['discountPercent'] ?? data['discountPercentage'],
      storeName: data['storeName'],
      category: data['category'],
      expiryDate: expiryDate,
      createdAt: createdAt,
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      shares: data['shares'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      sharedBy: List<String>.from(data['sharedBy'] ?? []),
      keywords: List<String>.from(data['keywords'] ?? []),
      rankingScore: (data['rankingScore'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
      isHot: data['isHot'] ?? false,
      isTrending: data['isTrending'] ?? false,
      isPinned: data['isPinned'] ?? false,
      isArchived: data['isArchived'] ?? false,
      isExpiringSoon: data['isExpiringSoon'] ?? false,
      externalUrl: data['externalUrl'],
      link: data['link'],
      disclaimer: data['disclaimer'] ?? 'Prices and availability may change.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'pastedText': pastedText,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'discountPrice': discountPrice,
      'discountPercent': discountPercent,
      'storeName': storeName,
      'category': category,
      'expiryDate': expiryDate.toIso8601String(),
      'views': views,
      'likes': likes,
      'shares': shares,
      'likedBy': likedBy,
      'sharedBy': sharedBy,
      'keywords': keywords,
      'rankingScore': rankingScore,
      'isActive': isActive,
      'isHot': isHot,
      'isTrending': isTrending,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isExpiringSoon': isExpiringSoon,
      'externalUrl': externalUrl,
      'link': link,
      'disclaimer': disclaimer,
    };
  }

  Deal copyWith({
    String? title,
    String? description,
    String? pastedText,
    String? imageUrl,
    double? originalPrice,
    double? discountPrice,
    int? discountPercent,
    String? storeName,
    String? category,
    DateTime? expiryDate,
    int? views,
    int? likes,
    int? shares,
    List<String>? likedBy,
    List<String>? sharedBy,
    List<String>? keywords,
    double? rankingScore,
    bool? isActive,
    bool? isHot,
    bool? isTrending,
    bool? isPinned,
    bool? isArchived,
    bool? isExpiringSoon,
    String? externalUrl,
    String? link,
    String? disclaimer,
  }) {
    return Deal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      pastedText: pastedText ?? this.pastedText,
      imageUrl: imageUrl ?? this.imageUrl,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPrice: discountPrice ?? this.discountPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      storeName: storeName ?? this.storeName,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      shares: shares ?? this.shares,
      likedBy: likedBy ?? this.likedBy,
      sharedBy: sharedBy ?? this.sharedBy,
      keywords: keywords ?? this.keywords,
      rankingScore: rankingScore ?? this.rankingScore,
      isActive: isActive ?? this.isActive,
      isHot: isHot ?? this.isHot,
      isTrending: isTrending ?? this.isTrending,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isExpiringSoon: isExpiringSoon ?? this.isExpiringSoon,
      externalUrl: externalUrl ?? this.externalUrl,
      link: link ?? this.link,
      disclaimer: disclaimer ?? this.disclaimer,
    );
  }

  Deal toggleHot() => copyWith(isHot: !isHot);
  Deal toggleTrending() => copyWith(isTrending: !isTrending);
  Deal togglePinned() => copyWith(isPinned: !isPinned);
  Deal toggleArchived() => copyWith(isArchived: !isArchived);

  Deal archive() => copyWith(isArchived: true);
  Deal unarchive() => copyWith(isArchived: false);
}
