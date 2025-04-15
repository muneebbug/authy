import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentinel/core/theme/app_theme.dart';
import 'package:sentinel/core/utils/auth_service.dart';
import 'package:sentinel/presentation/providers/auth_provider.dart';
import 'package:sentinel/presentation/screens/pin_setup_screen.dart';
import 'package:sentinel/presentation/widgets/dot_pattern_background.dart';
import 'package:sentinel/core/utils/settings_service.dart';
import 'dart:convert';

/// Settings screen with NothingOS design
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    // Auth-related providers
    final authMethod = ref.watch(authMethodProvider);
    final appLockEnabled = ref.watch(appLockProvider);
    final biometricAvailable =
        ref.watch(refreshableBiometricProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: GoogleFonts.spaceMono(
            letterSpacing: 1.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, size: 24),
            onPressed: () {
              // More options menu - placeholder
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dot pattern background
          const DotPatternBackground(),

          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Security section
                _buildSectionTitle('SECURITY', accentColor),
                const SizedBox(height: 12),

                _buildSettingsItem(
                  icon: Icons.fingerprint,
                  title: 'Biometric Authentication',
                  subtitle:
                      biometricAvailable
                          ? 'Use fingerprint to unlock the app'
                          : 'Not available on this device',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      biometricAvailable
                          ? TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  authMethod == AuthMethod.biometric
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.grey.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () async {
                              try {
                                if (authMethod != AuthMethod.biometric) {
                                  // Try to enable biometric
                                  final authenticated =
                                      await AuthService.authenticateWithBiometrics();
                                  if (authenticated) {
                                    await ref
                                        .read(authMethodProvider.notifier)
                                        .setBiometric();

                                    // Show success message
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Biometric authentication enabled',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } else {
                                    // Show error message
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Biometric authentication failed',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  // Disable biometric
                                  final hasPin = await AuthService.hasPin();
                                  if (hasPin) {
                                    await ref
                                        .read(authMethodProvider.notifier)
                                        .setAuthMethod(AuthMethod.pin);
                                  } else {
                                    await ref
                                        .read(authMethodProvider.notifier)
                                        .removeAuthentication();
                                  }

                                  // Show confirmation
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Biometric authentication disabled',
                                        ),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                print('Error toggling biometric auth: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              authMethod == AuthMethod.biometric
                                  ? 'ENABLED'
                                  : 'ENABLE',
                              style: TextStyle(
                                color:
                                    authMethod == AuthMethod.biometric
                                        ? Colors.green
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : const Text(
                            'Not Available',
                            style: TextStyle(color: Colors.grey),
                          ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.lock,
                  title: 'App Lock',
                  subtitle: 'Lock app when closed',
                  trailing: Switch(
                    value: appLockEnabled,
                    onChanged:
                        authMethod != AuthMethod.none
                            ? (value) async {
                              // If turning on app lock, make sure we have authentication
                              if (value && authMethod == AuthMethod.none) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please set up PIN or biometric authentication first',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              await ref
                                  .read(appLockProvider.notifier)
                                  .setAppLock(value);

                              // Show confirmation message
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      value
                                          ? 'App Lock enabled'
                                          : 'App Lock disabled',
                                    ),
                                    backgroundColor:
                                        value ? Colors.green : Colors.blue,
                                  ),
                                );
                              }
                            }
                            : null,
                  ),
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.pin,
                  title: 'PIN Code',
                  subtitle:
                      authMethod == AuthMethod.pin
                          ? 'PIN is set for authentication'
                          : 'Set a PIN for additional security',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (authMethod == AuthMethod.pin)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed:
                              () => _showRemovePinConfirmation(context, ref),
                        ),
                      const Icon(Icons.navigate_next),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PinSetupScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Appearance section
                _buildSectionTitle('APPEARANCE', accentColor),
                const SizedBox(height: 12),

                _buildSettingsItem(
                  icon: Icons.brightness_6,
                  title: 'Theme',
                  subtitle: _getThemeModeSubtitle(ref),
                  trailing: SizedBox(
                    width: 180,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildThemeModeButton(
                          context,
                          ref,
                          ThemeMode.light,
                          Icons.light_mode,
                        ),
                        const SizedBox(width: 8),
                        _buildThemeModeButton(
                          context,
                          ref,
                          ThemeMode.system,
                          Icons.brightness_auto,
                        ),
                        const SizedBox(width: 8),
                        _buildThemeModeButton(
                          context,
                          ref,
                          ThemeMode.dark,
                          Icons.dark_mode,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.palette,
                  title: 'Accent Color',
                  subtitle: 'Change app accent color',
                  trailing: SizedBox(
                    width: 140,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Show the current selected color with a larger circle
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        // Show a few preview colors balanced around the selected color
                        ..._buildPreviewColors(accentColorIndex, ref),
                      ],
                    ),
                  ),
                  onTap: () {
                    _showColorPickerSheet(context, ref, accentColorIndex);
                  },
                ),

                const SizedBox(height: 24),

                // Data & Backup section
                _buildSectionTitle('DATA & BACKUP', accentColor),
                const SizedBox(height: 12),

                _buildSettingsItem(
                  icon: Icons.sync,
                  title: 'Auto Backup',
                  subtitle: 'Backup accounts to cloud',
                  trailing: Switch(
                    value: false, // Placeholder
                    onChanged: (value) {
                      // Placeholder
                    },
                  ),
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.download,
                  title: 'Export Accounts',
                  subtitle: 'Export as encrypted file',
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    // Placeholder
                  },
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.upload,
                  title: 'Import Accounts',
                  subtitle: 'Import from file',
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    // Placeholder
                  },
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.settings_backup_restore,
                  title: 'Settings Sync',
                  subtitle: 'View settings in sync-ready format',
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () => _showSettingsExportDialog(context),
                ),

                const SizedBox(height: 24),

                // About section
                _buildSectionTitle('ABOUT', accentColor),
                const SizedBox(height: 12),

                _buildSettingsItem(
                  icon: Icons.info,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.group,
                  title: 'Follow Us',
                  subtitle: 'Stay updated',
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    // Placeholder
                  },
                ),

                const SizedBox(height: 8),
                _buildSettingsItem(
                  icon: Icons.email,
                  title: 'Contact Support',
                  subtitle: 'Get help',
                  trailing: const Icon(Icons.navigate_next),
                  onTap: () {
                    // Placeholder
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build section title
  Widget _buildSectionTitle(String title, Color accentColor) {
    return Text(
      title,
      style: GoogleFonts.spaceMono(
        color: accentColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  // Build an individual settings item
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final brightness = theme.brightness;

        return Container(
          decoration: AppTheme.settingsItemDecoration(brightness),
          margin: const EdgeInsets.only(bottom: 1),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          brightness == Brightness.dark
                              ? Colors.black26
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 16),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.spaceMono(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.getOnSurfaceColor(brightness),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.spaceMono(
                            color:
                                brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trailing widget (switch, button, etc)
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build a color option for the quick selection
  Widget _buildColorOption(
    WidgetRef ref,
    int index,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(accentColorProvider.notifier).setAccentColor(index);
      },
      child: Container(
        width: isSelected ? 28 : 18,
        height: isSelected ? 28 : 18,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  // Show bottom sheet with all color options
  void _showColorPickerSheet(
    BuildContext context,
    WidgetRef ref,
    int currentIndex,
  ) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow the sheet to be taller
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                0.7, // Limit height to 70% of screen
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle at the top
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Select Accent Color',
                  style: GoogleFonts.spaceMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Choose from 10 beautiful colors',
                  style: GoogleFonts.spaceMono(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24),

                // Current selected color preview
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.getAccentColor(currentIndex),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.getAccentColor(
                                currentIndex,
                              ).withOpacity(0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Show the color name
                      Text(
                        AppTheme.accentColorNames[currentIndex],
                        style: GoogleFonts.spaceMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getAccentColor(currentIndex),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Color grid with constrained width
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: screenWidth - 40, // Allow some padding
                    ),
                    child: Wrap(
                      spacing:
                          screenWidth < 360
                              ? 12
                              : 16, // Smaller spacing on small screens
                      runSpacing:
                          20, // Slightly reduced to prevent vertical overflow
                      alignment: WrapAlignment.center,
                      children: List.generate(AppTheme.accentColors.length, (
                        index,
                      ) {
                        // Calculate size based on screen width to fit 5 colors per row on any screen
                        final colorSize = ((screenWidth - 80) / 5).clamp(
                          40.0,
                          50.0,
                        );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Color option
                            GestureDetector(
                              onTap: () {
                                ref
                                    .read(accentColorProvider.notifier)
                                    .setAccentColor(index);
                                Navigator.pop(context);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: colorSize,
                                height: colorSize,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColors[index],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        index == currentIndex
                                            ? Colors.white
                                            : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentColors[index]
                                          .withOpacity(
                                            index == currentIndex ? 0.4 : 0.2,
                                          ),
                                      blurRadius: index == currentIndex ? 8 : 4,
                                      spreadRadius:
                                          index == currentIndex ? 1 : 0,
                                    ),
                                  ],
                                ),
                                child:
                                    index == currentIndex
                                        ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                            ),

                            // Small label below current selection
                            if (index == currentIndex) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                width: colorSize + 10,
                                child: Text(
                                  AppTheme.accentColorNames[index],
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 9,
                                    color: Colors.grey.shade300,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build a few preview colors balanced around the selected color
  List<Widget> _buildPreviewColors(int currentIndex, WidgetRef ref) {
    final colors = AppTheme.accentColors;
    final List<Widget> previewColors = [];

    // Select 3 other colors to show as preview (plus "more" indicator)
    // Always display the same colors regardless of selection to avoid overflow
    List<int> indicesToShow = [0, 2, 5, 7];

    // Remove current index if it's in the preview list
    if (indicesToShow.contains(currentIndex)) {
      indicesToShow.remove(currentIndex);
    }

    // Only show first 3 colors from the list
    indicesToShow = indicesToShow.take(3).toList();

    // Add the preview color circles
    for (int i in indicesToShow) {
      previewColors.add(
        _buildColorOption(ref, i, AppTheme.accentColors[i], false),
      );
    }

    // Add a "more" indicator
    previewColors.add(
      Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_horiz, size: 12, color: Colors.white70),
      ),
    );

    return previewColors;
  }

  // Show confirmation dialog for removing PIN
  void _showRemovePinConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Remove PIN?'),
            content: const Text(
              'Removing the PIN will disable authentication. Your accounts will be accessible without verification.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(authMethodProvider.notifier).removeAuthentication();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'REMOVE',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }

  // Show settings export dialog
  void _showSettingsExportDialog(BuildContext context) async {
    // Get current settings
    final settings = await SettingsService.getFullSettings();
    final prettyJson = const JsonEncoder.withIndent('  ').convert(settings);

    if (context.mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppTheme.surface,
              title: const Text('Settings JSON'),
              content: Container(
                width: double.maxFinite,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    prettyJson,
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      color: Colors.grey[300],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
      );
    }
  }

  // Build a theme mode button
  Widget _buildThemeModeButton(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isSelected = ref.watch(themeModeProvider) == mode;
    final accentColorIndex = ref.watch(accentColorProvider);
    final accentColor = AppTheme.getAccentColor(accentColorIndex);

    return TextButton(
      onPressed: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(50, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Container(
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color:
              isSelected
                  ? accentColor
                  : brightness == Brightness.dark
                  ? Colors.black26
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color:
              isSelected
                  ? AppTheme.getTextColor(accentColor)
                  : brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[700],
          size: 20,
        ),
      ),
    );
  }

  // Get theme mode subtitle
  String _getThemeModeSubtitle(WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.dark:
        return 'Dark mode';
      default:
        throw Exception('Unknown theme mode');
    }
  }
}
