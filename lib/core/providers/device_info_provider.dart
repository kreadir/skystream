import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceProfile {
  final bool isTv;
  final bool isDesktop;
  final bool isMobile; // Phone or Tablet

  const DeviceProfile({
    this.isTv = false,
    this.isDesktop = false,
    this.isMobile = true,
  });

  bool get isLargeScreen => isTv || isDesktop;
}

final deviceProfileProvider = FutureProvider<DeviceProfile>((ref) async {
  bool isTv = false;
  bool isDesktop = false;

  if (kIsWeb) {
    // Web logic if needed
  } else {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      isTv = androidInfo.systemFeatures.contains('android.software.leanback');
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      isDesktop = true;
    }
  }

  // If not Tv and not Desktop, it's mobile (phone or tablet)
  // We don't distinguish tablet here strictly via OS features usually, 
  // responsive UI handles the rest.
  
  return DeviceProfile(
    isTv: isTv,
    isDesktop: isDesktop,
    isMobile: !isTv && !isDesktop,
  );
});
