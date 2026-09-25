import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/business_profile_service.dart';
import '../../data/database.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      _SidebarItem(Icons.dashboard_rounded, 'Dashboard'),
      _SidebarItem(Icons.people_rounded, 'Ledgers & Accounts'),
      _SidebarItem(Icons.inventory_2_rounded, 'Inventory / Stock'),
      _SidebarItem(Icons.receipt_long_rounded, 'Sales & Purchases'),
      _SidebarItem(Icons.payment_rounded, 'Receipts & Payments'),
      _SidebarItem(Icons.assessment_rounded, 'Financial Reports'),
      _SidebarItem(Icons.swap_vertical_circle_rounded, 'Import / Export'),
      _SidebarItem(Icons.settings_rounded, 'Settings'),
    ];

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Branding
          FutureBuilder<BusinessProfile>(
            future: BusinessProfileService(Provider.of<AppDatabase>(context, listen: false)).getProfile(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final logoPath = profile?.logoPath;
              final hasLogo = logoPath != null && File(logoPath).existsSync();
              final companyName = (profile?.companyName != null && profile!.companyName.isNotEmpty)
                  ? profile.companyName
                  : 'TALLY LEDGER';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: hasLogo ? Colors.transparent : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: hasLogo ? Border.all(color: AppColors.border) : null,
                      ),
                      child: hasLogo
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(logoPath), fit: BoxFit.contain),
                            )
                          : const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companyName.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'PRO EDITION v1.1',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Menu Items
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = index == currentIndex;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBackground : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: const Color(0xFFBFDBFE), width: 1)
                            : Border.all(color: Colors.transparent, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Database Status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSecondary,
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  radius: 7,
                  child: const CircleAvatar(
                    backgroundColor: AppColors.success,
                    radius: 3.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Local DB Active',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textMuted,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;

  _SidebarItem(this.icon, this.label);
}
