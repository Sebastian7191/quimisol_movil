import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AnimatedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AnimatedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = const [
      _NavItemData(icon: Icons.home_rounded, label: 'Home'),
      _NavItemData(icon: Icons.search_rounded, label: 'Buscar'),
      _NavItemData(icon: Icons.shopping_basket_rounded, label: 'Carrito'),
      _NavItemData(icon: Icons.person_rounded, label: 'Perfil'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            items.length,
            (index) => _AnimatedNavItem(
              data: items[index],
              isSelected: index == currentIndex,
              onTap: () => onTabSelected(index),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}

class _AnimatedNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Duration duration = const Duration(milliseconds: 250);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutQuad,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Palette.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: duration,
              scale: isSelected ? 1.1 : 1.0,
              child: Icon(
                data.icon,
                size: 22,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
            ),
            AnimatedSize(
              duration: duration,
              curve: Curves.easeOutQuad,
              child: Padding(
                padding: EdgeInsets.only(left: isSelected ? 8 : 0),
                child: isSelected
                    ? Text(
                        data.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
