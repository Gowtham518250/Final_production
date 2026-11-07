import 'package:flutter/material.dart';

class GrowthPosterStyle {
  const GrowthPosterStyle({
    required this.id,
    required this.title,
    required this.colors,
    required this.accent,
    required this.accentText,
    required this.icon,
    this.light = false,
    this.blessing = false,
    this.blessingName = '',
    this.symbol = '',
  });

  final String id;
  final String title;
  final List<Color> colors;
  final Color accent;
  final Color accentText;
  final IconData icon;
  final bool light;
  final bool blessing;
  final String blessingName;
  final String symbol;

  static const userPrefix = 'god_user_';

  static GrowthPosterStyle userGod({
    required String id,
    required String title,
  }) {
    return GrowthPosterStyle(
      id: id,
      title: title,
      blessing: true,
      blessingName: title,
      symbol: 'ॐ',
      colors: [Color(0xFF7C2D12), Color(0xFFCA8A04), Color(0xFFFACC15)],
      accent: Color(0xFFFEF3C7),
      accentText: Color(0xFF7C2D12),
      icon: Icons.temple_hindu_rounded,
    );
  }
}

class GrowthPosterCatalog {
  static const List<GrowthPosterStyle> all = [
    GrowthPosterStyle(
      id: 'emerald',
      title: 'Emerald market',
      colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF84CC16)],
      accent: Color(0xFFD9F99D),
      accentText: Color(0xFF14532D),
      icon: Icons.eco_rounded,
    ),
    GrowthPosterStyle(
      id: 'mint',
      title: 'Mint aisle',
      colors: [Color(0xFF134E4A), Color(0xFF14B8A6), Color(0xFF99F6E4)],
      accent: Color(0xFFCCFBF1),
      accentText: Color(0xFF115E59),
      icon: Icons.spa_rounded,
    ),
    GrowthPosterStyle(
      id: 'forest',
      title: 'Forest stall',
      colors: [Color(0xFF14532D), Color(0xFF166534), Color(0xFF4ADE80)],
      accent: Color(0xFFBBF7D0),
      accentText: Color(0xFF14532D),
      icon: Icons.park_rounded,
    ),
    GrowthPosterStyle(
      id: 'lime',
      title: 'Lime board',
      colors: [Color(0xFF365314), Color(0xFF65A30D), Color(0xFFA3E635)],
      accent: Color(0xFFECFCCB),
      accentText: Color(0xFF3F6212),
      icon: Icons.grass_rounded,
    ),
    GrowthPosterStyle(
      id: 'saffron',
      title: 'Saffron offer',
      colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFBBF24)],
      accent: Color(0xFFFEF3C7),
      accentText: Color(0xFF7C2D12),
      icon: Icons.wb_sunny_rounded,
    ),
    GrowthPosterStyle(
      id: 'mango',
      title: 'Mango stall',
      colors: [Color(0xFF78350F), Color(0xFFF59E0B), Color(0xFFFDE047)],
      accent: Color(0xFFFEF9C3),
      accentText: Color(0xFF713F12),
      icon: Icons.local_dining_rounded,
    ),
    GrowthPosterStyle(
      id: 'sunset',
      title: 'Sunset sale',
      colors: [Color(0xFF9A3412), Color(0xFFFB7185), Color(0xFFF97316)],
      accent: Color(0xFFFFEDD5),
      accentText: Color(0xFF9A3412),
      icon: Icons.wb_twilight_rounded,
    ),
    GrowthPosterStyle(
      id: 'ruby',
      title: 'Ruby festive',
      colors: [Color(0xFF7F1D1D), Color(0xFFDC2626), Color(0xFFF97316)],
      accent: Color(0xFFFDE68A),
      accentText: Color(0xFF422006),
      icon: Icons.celebration_rounded,
    ),
    GrowthPosterStyle(
      id: 'rose',
      title: 'Rose shop',
      colors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB7185)],
      accent: Color(0xFFFFE4E6),
      accentText: Color(0xFF9F1239),
      icon: Icons.favorite_rounded,
    ),
    GrowthPosterStyle(
      id: 'coral',
      title: 'Coral counter',
      colors: [Color(0xFF9A3412), Color(0xFFF43F5E), Color(0xFFFB923C)],
      accent: Color(0xFFFFE4E6),
      accentText: Color(0xFF9F1239),
      icon: Icons.local_offer_rounded,
    ),
    GrowthPosterStyle(
      id: 'lotus',
      title: 'Lotus festive',
      colors: [Color(0xFF701A75), Color(0xFFDB2777), Color(0xFFF9A8D4)],
      accent: Color(0xFFFCE7F3),
      accentText: Color(0xFF9D174D),
      icon: Icons.local_florist_rounded,
    ),
    GrowthPosterStyle(
      id: 'navy',
      title: 'Navy board',
      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF38BDF8)],
      accent: Color(0xFFBAE6FD),
      accentText: Color(0xFF0C4A6E),
      icon: Icons.storefront_rounded,
    ),
    GrowthPosterStyle(
      id: 'indigo',
      title: 'Indigo spotlight',
      colors: [Color(0xFF101638), Color(0xFF4C1D95), Color(0xFF7C3AED)],
      accent: Color(0xFFFDE68A),
      accentText: Color(0xFF422006),
      icon: Icons.shopping_bag_rounded,
    ),
    GrowthPosterStyle(
      id: 'violet',
      title: 'Violet glow',
      colors: [Color(0xFF2E1065), Color(0xFF7C3AED), Color(0xFFC084FC)],
      accent: Color(0xFFEDE9FE),
      accentText: Color(0xFF5B21B6),
      icon: Icons.auto_awesome_rounded,
    ),
    GrowthPosterStyle(
      id: 'grape',
      title: 'Grape night',
      colors: [Color(0xFF3B0764), Color(0xFFA21CAF), Color(0xFFE879F9)],
      accent: Color(0xFFFAE8FF),
      accentText: Color(0xFF86198F),
      icon: Icons.nightlife_rounded,
    ),
    GrowthPosterStyle(
      id: 'royal',
      title: 'Royal blue',
      colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF60A5FA)],
      accent: Color(0xFFDBEAFE),
      accentText: Color(0xFF1E3A8A),
      icon: Icons.workspace_premium_rounded,
    ),
    GrowthPosterStyle(
      id: 'ocean',
      title: 'Ocean bay',
      colors: [Color(0xFF0C4A6E), Color(0xFF0284C7), Color(0xFF38BDF8)],
      accent: Color(0xFFE0F2FE),
      accentText: Color(0xFF075985),
      icon: Icons.water_rounded,
    ),
    GrowthPosterStyle(
      id: 'teal',
      title: 'Teal counter',
      colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF2DD4BF)],
      accent: Color(0xFFCCFBF1),
      accentText: Color(0xFF115E59),
      icon: Icons.inventory_2_rounded,
    ),
    GrowthPosterStyle(
      id: 'sky',
      title: 'Sky stall',
      colors: [Color(0xFF075985), Color(0xFF0EA5E9), Color(0xFF7DD3FC)],
      accent: Color(0xFFF0F9FF),
      accentText: Color(0xFF0C4A6E),
      icon: Icons.cloud_rounded,
    ),
    GrowthPosterStyle(
      id: 'midnight',
      title: 'Midnight shop',
      colors: [Color(0xFF020617), Color(0xFF1E293B), Color(0xFF64748B)],
      accent: Color(0xFFE2E8F0),
      accentText: Color(0xFF0F172A),
      icon: Icons.dark_mode_rounded,
    ),
    GrowthPosterStyle(
      id: 'gold',
      title: 'Gold festival',
      colors: [Color(0xFF713F12), Color(0xFFCA8A04), Color(0xFFFACC15)],
      accent: Color(0xFFFEFCE8),
      accentText: Color(0xFF713F12),
      icon: Icons.star_rounded,
    ),
    GrowthPosterStyle(
      id: 'bronze',
      title: 'Bronze bazaar',
      colors: [Color(0xFF44403C), Color(0xFFB45309), Color(0xFFD6D3D1)],
      accent: Color(0xFFFFEDD5),
      accentText: Color(0xFF7C2D12),
      icon: Icons.hardware_rounded,
    ),
    GrowthPosterStyle(
      id: 'graphite',
      title: 'Graphite board',
      colors: [Color(0xFF111827), Color(0xFF374151), Color(0xFF9CA3AF)],
      accent: Color(0xFFF3F4F6),
      accentText: Color(0xFF111827),
      icon: Icons.grid_view_rounded,
    ),
    GrowthPosterStyle(
      id: 'ivory',
      title: 'Ivory update',
      colors: [Color(0xFFF8FAFC), Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
      accent: Color(0xFFBE123C),
      accentText: Colors.white,
      icon: Icons.storefront_rounded,
      light: true,
    ),
  ];

  static const List<GrowthPosterStyle> blessings = [
    GrowthPosterStyle(
      id: 'ganesha',
      title: 'Ganesha',
      blessing: true,
      blessingName: 'Ganesha',
      symbol: 'ॐ',
      colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFBBF24)],
      accent: Color(0xFFFEF3C7),
      accentText: Color(0xFF7C2D12),
      icon: Icons.temple_hindu_rounded,
    ),
    GrowthPosterStyle(
      id: 'lakshmi',
      title: 'Lakshmi',
      blessing: true,
      blessingName: 'Lakshmi',
      symbol: 'ॐ',
      colors: [Color(0xFF7F1D1D), Color(0xFFB45309), Color(0xFFFACC15)],
      accent: Color(0xFFFEF9C3),
      accentText: Color(0xFF713F12),
      icon: Icons.auto_awesome_rounded,
    ),
    GrowthPosterStyle(
      id: 'saraswati',
      title: 'Saraswati',
      blessing: true,
      blessingName: 'Saraswati',
      symbol: 'ॐ',
      colors: [Color(0xFFFFF7ED), Color(0xFFFFFFFF), Color(0xFFFEF3C7)],
      accent: Color(0xFF1D4ED8),
      accentText: Colors.white,
      icon: Icons.menu_book_rounded,
      light: true,
    ),
    GrowthPosterStyle(
      id: 'krishna',
      title: 'Krishna',
      blessing: true,
      blessingName: 'Krishna',
      symbol: 'ॐ',
      colors: [Color(0xFF1E3A8A), Color(0xFF0369A1), Color(0xFF4ADE80)],
      accent: Color(0xFFFEF08A),
      accentText: Color(0xFF713F12),
      icon: Icons.music_note_rounded,
    ),
    GrowthPosterStyle(
      id: 'durga',
      title: 'Durga',
      blessing: true,
      blessingName: 'Durga',
      symbol: 'ॐ',
      colors: [Color(0xFF7F1D1D), Color(0xFFBE123C), Color(0xFFF59E0B)],
      accent: Color(0xFFFDE68A),
      accentText: Color(0xFF422006),
      icon: Icons.shield_rounded,
    ),
    GrowthPosterStyle(
      id: 'hanuman',
      title: 'Hanuman',
      blessing: true,
      blessingName: 'Hanuman',
      symbol: 'ॐ',
      colors: [Color(0xFF9A3412), Color(0xFFEA580C), Color(0xFFFDBA74)],
      accent: Color(0xFFFFEDD5),
      accentText: Color(0xFF7C2D12),
      icon: Icons.fitness_center_rounded,
    ),
    GrowthPosterStyle(
      id: 'shiva',
      title: 'Shiva',
      blessing: true,
      blessingName: 'Shiva',
      symbol: 'ॐ',
      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF67E8F9)],
      accent: Color(0xFFE0F2FE),
      accentText: Color(0xFF0C4A6E),
      icon: Icons.nights_stay_rounded,
    ),
    GrowthPosterStyle(
      id: 'venkateswara',
      title: 'Balaji',
      blessing: true,
      blessingName: 'Venkateswara',
      symbol: 'ॐ',
      colors: [Color(0xFF713F12), Color(0xFFB45309), Color(0xFFFDE047)],
      accent: Color(0xFFFEFCE8),
      accentText: Color(0xFF713F12),
      icon: Icons.account_balance_rounded,
    ),
    GrowthPosterStyle(
      id: 'ayyappa',
      title: 'Ayyappa',
      blessing: true,
      blessingName: 'Ayyappa',
      symbol: 'ॐ',
      colors: [Color(0xFF111827), Color(0xFF44403C), Color(0xFFFACC15)],
      accent: Color(0xFFFEF3C7),
      accentText: Color(0xFF422006),
      icon: Icons.hiking_rounded,
    ),
    GrowthPosterStyle(
      id: 'sai',
      title: 'Sai Baba',
      blessing: true,
      blessingName: 'Sai Baba',
      symbol: 'ॐ',
      colors: [Color(0xFF9A3412), Color(0xFFFB923C), Color(0xFFFFF7ED)],
      accent: Color(0xFFFFEDD5),
      accentText: Color(0xFF7C2D12),
      icon: Icons.volunteer_activism_rounded,
    ),
    GrowthPosterStyle(
      id: 'murugan',
      title: 'Murugan',
      blessing: true,
      blessingName: 'Murugan',
      symbol: 'ॐ',
      colors: [Color(0xFF9F1239), Color(0xFFDB2777), Color(0xFF38BDF8)],
      accent: Color(0xFFFEF9C3),
      accentText: Color(0xFF713F12),
      icon: Icons.flash_on_rounded,
    ),
    GrowthPosterStyle(
      id: 'jagannath',
      title: 'Jagannath',
      blessing: true,
      blessingName: 'Jagannath',
      symbol: 'ॐ',
      colors: [Color(0xFFB45309), Color(0xFFDC2626), Color(0xFFFACC15)],
      accent: Color(0xFFFEF3C7),
      accentText: Color(0xFF7C2D12),
      icon: Icons.wb_sunny_rounded,
    ),
    GrowthPosterStyle(
      id: 'radha',
      title: 'Radha Krishna',
      blessing: true,
      blessingName: 'Radha Krishna',
      symbol: 'ॐ',
      colors: [Color(0xFF9D174D), Color(0xFF2563EB), Color(0xFFF9A8D4)],
      accent: Color(0xFFFCE7F3),
      accentText: Color(0xFF9D174D),
      icon: Icons.favorite_rounded,
    ),
    GrowthPosterStyle(
      id: 'annapurna',
      title: 'Annapurna',
      blessing: true,
      blessingName: 'Annapurna',
      symbol: 'ॐ',
      colors: [Color(0xFF7C2D12), Color(0xFFCA8A04), Color(0xFFFDE68A)],
      accent: Color(0xFFFEFCE8),
      accentText: Color(0xFF713F12),
      icon: Icons.restaurant_rounded,
    ),
    GrowthPosterStyle(
      id: 'deepam',
      title: 'Deepam',
      blessing: true,
      blessingName: 'Deepam',
      symbol: 'ॐ',
      colors: [Color(0xFF431407), Color(0xFFEA580C), Color(0xFFFDE047)],
      accent: Color(0xFFFFFBEB),
      accentText: Color(0xFF78350F),
      icon: Icons.light_mode_rounded,
    ),
  ];

  static const aliases = {
    'bold': 'indigo',
    'festive': 'ruby',
    'fresh': 'emerald',
    'minimal': 'ivory',
  };

  static List<GrowthPosterStyle> get every => [...all, ...blessings];

  static bool accepts(String id) {
    if (id.startsWith(GrowthPosterStyle.userPrefix)) return true;
    final resolved = aliases[id] ?? id;
    return every.any((style) => style.id == resolved);
  }

  static GrowthPosterStyle of(String id) {
    final resolved = aliases[id] ?? id;
    return every.firstWhere(
      (style) => style.id == resolved,
      orElse: () => id.startsWith(GrowthPosterStyle.userPrefix)
          ? GrowthPosterStyle.userGod(id: id, title: 'God image')
          : all.first,
    );
  }
}
