import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/core/theme/app_theme.dart';
import 'package:sentinel/presentation/screens/settings_screen.dart';

/// Drawer widget with NothingOS style
class AppDrawer extends ConsumerWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer header
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App logo
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor, width: 2.0),
                      ),
                      child: Center(
                        child: Text(
                          'S',
                          style: GoogleFonts.spaceMono(
                            color: accentColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SENTINEL',
                      style: GoogleFonts.spaceMono(
                        fontSize: 20,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Menu items
            _buildMenuItem(
              context: context,
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
              },
              isSelected: true,
              accentColor: accentColor,
            ),

            _buildMenuItem(
              context: context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              accentColor: accentColor,
            ),

            _buildMenuItem(
              context: context,
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to About screen
              },
              accentColor: accentColor,
            ),

            const Spacer(),

            // App version at bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Version 1.0.0',
                style: GoogleFonts.spaceMono(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    required Color accentColor,
  }) {
    final color = isSelected ? accentColor : Colors.white;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: GoogleFonts.spaceMono(color: color, letterSpacing: 0.5),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Colors.grey.shade900,
    );
  }
}
