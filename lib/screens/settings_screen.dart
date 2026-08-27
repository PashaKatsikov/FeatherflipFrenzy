import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_version.dart';
import '../core/assets.dart';
import '../core/audio_service.dart';
import '../core/haptics.dart';
import '../core/notification_service.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/ff_back_button.dart';
import '../widgets/menu_background.dart';
import 'webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pickingPhoto = false;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (!mounted || file == null) return;
      final ok = await context.read<AppState>().setProfilePhotoFromPath(file.path);
      if (!mounted) return;
      if (ok) {
        AudioService.instance.playSfx(Sfx.rewardCollect);
        Haptics.instance.light();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save that photo. Please try another one.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Camera is unavailable. Try choosing a photo from your library.'
                : 'Could not open the photo library.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _confirmRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FFColors.panelBrown,
        title: Text('Remove photo?', style: FFText.heading(size: 20)),
        content: Text(
          'Your farmyard profile will go back to the default hen portrait.',
          style: FFText.body(size: 15, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Keep', style: FFText.body(size: 15, color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: FFText.body(size: 15, color: FFColors.warmYellow)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().clearProfilePhoto();
    AudioService.instance.playSfx(Sfx.menuClose);
  }

  Future<void> _setNotificationsOn(bool enabled, AppState appState) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications are off in iOS Settings. Enable them to hear the coop call.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await appState.setNotificationsOn(true);
      await NotificationService.instance.scheduleDaily(
        hour: appState.notificationHour,
        minute: appState.notificationMinute,
      );
      AudioService.instance.playSfx(Sfx.buttonTap);
      return;
    }
    await appState.setNotificationsOn(false);
    await NotificationService.instance.cancelDaily();
    AudioService.instance.playSfx(Sfx.menuClose);
  }

  Future<void> _pickNotificationTime(AppState appState) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: appState.notificationHour, minute: appState.notificationMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: FFColors.panelBrown,
              hourMinuteTextColor: Colors.white,
              dialHandColor: FFColors.gold,
              entryModeIconColor: FFColors.warmYellow,
            ),
            colorScheme: const ColorScheme.dark(
              primary: FFColors.gold,
              onPrimary: FFColors.textDark,
              surface: FFColors.panelBrown,
              onSurface: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    await appState.setNotificationTime(picked.hour, picked.minute);
    if (appState.notificationsOn) {
      await NotificationService.instance.scheduleDaily(hour: picked.hour, minute: picked.minute);
    }
    AudioService.instance.playSfx(Sfx.elementSelect);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MenuBackground(
      vista: Sprites.pastureVista,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FFBackButton(onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 16),
                Text('Settings', style: FFText.title(size: 26)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 480,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8A5A34), FFColors.panelBrown], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFD9A971), width: 3),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _ProfilePhotoRow(
                            photoPath: appState.profilePhotoPath,
                            nonce: appState.profilePhotoNonce,
                            busy: _pickingPhoto,
                            onCamera: () => _pickPhoto(ImageSource.camera),
                            onGallery: () => _pickPhoto(ImageSource.gallery),
                            onRemove: appState.profilePhotoPath == null ? null : _confirmRemovePhoto,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: Colors.white24, height: 1),
                          ),
                          _ToggleRow(
                            icon: Icons.volume_up_rounded,
                            label: 'Sound Effects',
                            value: appState.sfxOn,
                            onChanged: (v) {
                              appState.setSfxOn(v);
                              AudioService.instance.setSfxEnabled(v);
                              if (v) AudioService.instance.playSfx(Sfx.buttonTap);
                            },
                          ),
                          _ToggleRow(
                            icon: Icons.vibration_rounded,
                            label: 'Vibration',
                            value: appState.vibrationOn,
                            onChanged: (v) {
                              appState.setVibrationOn(v);
                              Haptics.instance.setEnabled(v);
                              if (v) Haptics.instance.light();
                            },
                          ),
                          _ToggleRow(
                            icon: Icons.hd_rounded,
                            label: 'Extra Visual Effects',
                            value: appState.highGraphics,
                            onChanged: appState.setHighGraphics,
                          ),
                          _ToggleRow(
                            icon: Icons.notifications_active_rounded,
                            label: 'Daily Coop Reminder',
                            value: appState.notificationsOn,
                            onChanged: (v) => _setNotificationsOn(v, appState),
                          ),
                          if (appState.notificationsOn)
                            _NotificationTimeRow(
                              hour: appState.notificationHour,
                              minute: appState.notificationMinute,
                              onTap: () => _pickNotificationTime(appState),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(color: Colors.white24, height: 1),
                          ),
                          _LinkRow(
                            icon: Icons.privacy_tip_rounded,
                            label: 'Privacy Policy',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FFWebViewScreen(title: 'Privacy Policy', url: AppLinks.privacyPolicy),
                              ),
                            ),
                          ),
                          _LinkRow(
                            icon: Icons.support_agent_rounded,
                            label: 'Support',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FFWebViewScreen(title: 'Support', url: AppLinks.support),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(AppVersion.display, style: FFText.body(size: 12, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoRow extends StatelessWidget {
  final String? photoPath;
  final int nonce;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  const _ProfilePhotoRow({
    required this.photoPath,
    required this.nonce,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfileAvatar(path: photoPath, nonce: nonce, busy: busy),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile Photo', style: FFText.body(size: 16, color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                'Show your face in the farmyard, or keep the hen portrait.',
                style: FFText.body(size: 12, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PhotoChip(icon: Icons.photo_camera_rounded, label: 'Camera', onTap: busy ? null : onCamera),
                  _PhotoChip(icon: Icons.photo_library_rounded, label: 'Gallery', onTap: busy ? null : onGallery),
                  if (onRemove != null) _PhotoChip(icon: Icons.close_rounded, label: 'Remove', onTap: busy ? null : onRemove),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? path;
  final int nonce;
  final bool busy;
  const _ProfileAvatar({required this.path, required this.nonce, required this.busy});

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final hasFile = file != null && file.existsSync();
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9A971), width: 3),
        color: FFColors.panelBrownDark,
      ),
      clipBehavior: Clip.antiAlias,
      child: busy
          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: FFColors.gold)))
          : hasFile
              ? Image.file(file, key: ValueKey('$path-$nonce'), fit: BoxFit.cover)
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(Sprites.chickenMain, fit: BoxFit.contain),
                ),
    );
  }
}

class _PhotoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PhotoChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              AudioService.instance.playSfx(Sfx.buttonTap);
              onTap!();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: FFColors.panelBrownDark.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9A971), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FFColors.warmYellow, size: 16),
            const SizedBox(width: 6),
            Text(label, style: FFText.body(size: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: FFColors.warmYellow, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: FFText.body(size: 16, color: Colors.white))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FFColors.gold,
          ),
        ],
      ),
    );
  }
}

class _NotificationTimeRow extends StatelessWidget {
  final int hour;
  final int minute;
  final VoidCallback onTap;
  const _NotificationTimeRow({required this.hour, required this.minute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = TimeOfDay(hour: hour, minute: minute).format(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        AudioService.instance.playSfx(Sfx.buttonTap);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(38, 4, 0, 10),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: FFColors.warmYellow, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text('Remind me at $label', style: FFText.body(size: 15, color: Colors.white))),
            const Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        AudioService.instance.playSfx(Sfx.buttonTap);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: FFText.body(size: 16, color: Colors.white))),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
