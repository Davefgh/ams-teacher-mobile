import 'package:flutter/material.dart';

class CompactHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final bool showBackButton;

  const CompactHeader({
    super.key,
    required this.title,
    this.onBackPressed,
    this.onActionPressed,
    this.actionIcon,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Back Button (optional)
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
            ),
          if (showBackButton) const SizedBox(width: 12),

          // ACLC Logo
          Image.asset(
            'lib/images/aclc_logo.png',
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),

          // Action Button (optional)
          if (actionIcon != null)
            IconButton(
              icon: Icon(actionIcon, color: Colors.white, size: 28),
              onPressed: onActionPressed,
            ),
        ],
      ),
    );
  }
}
