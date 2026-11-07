import 'live_translated_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'visual_widgets.dart';

/// Modern SaaS bottom navigation bar
/// 5 tabs: Home, Analytics, Add Sale (center), Store, AI
class AppBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  bool _isOwner = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final prefs = await SharedPreferences.getInstance();
    final isStaff = prefs.getBool('is_staff_mode') ?? false;
    if (mounted) {
      setState(() {
        _isOwner = !isStaff;
      });
    }
  }

  void _handleRestrictedTap(int index) {
    if (!_isOwner && (index == 1 || index == 3 || index == 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LiveTranslatedText(
            'Access Denied: Owner Privileges Required',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. HOME / DASHBOARD
              _ModernNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: widget.currentIndex == 0,
                activeColor: const Color(0xFF2563EB), // Blue
                onTap: () => _handleRestrictedTap(0),
              ),

              // 2. ADD SALE (Center - Prominent)
              _CenterActionButton(onTap: () => _handleRestrictedTap(1)),

              // 3. STORE / MODULES
              _ModernNavItem(
                icon: Icons.storefront_rounded,
                label: 'Store',
                isActive: widget.currentIndex == 2,
                activeColor: const Color(0xFFEA580C), // Orange
                onTap: () => _handleRestrictedTap(2),
              ),

              // 4. AI CHATBOT
              _ModernNavItem(
                icon: Icons.smart_toy_rounded,
                label: 'AI',
                isActive: widget.currentIndex == 3,
                activeColor: const Color(0xFF9333EA), // Purple
                onTap: () => _handleRestrictedTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern navigation item widget
class _ModernNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? activeColor
                    : AppColors.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(height: 3),
            LiveTranslatedText(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? activeColor
                    : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Center action button for Add Sale
class _CenterActionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CenterActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16A34A), Color(0xFF22C55E)], // Green gradient
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4016A34A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 3),
            LiveTranslatedText(
              'Add',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
