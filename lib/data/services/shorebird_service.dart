import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../../global/helper/app_snackbar.dart';

class ShorebirdService extends GetxService {
  static ShorebirdService get instance =>
      Get.isRegistered<ShorebirdService>()
          ? Get.find<ShorebirdService>()
          : Get.put(ShorebirdService(), permanent: true);

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  final RxBool isAvailable = false.obs;
  final RxBool isChecking = false.obs;
  final RxBool isDownloading = false.obs;
  final RxBool hasPendingRestart = false.obs;
  final Rxn<Patch> currentPatch = Rxn<Patch>();
  final Rxn<Patch> nextPatch = Rxn<Patch>();

  /// Returns a formatted patch label, e.g. "Patch #2" or "Base release"
  String get patchLabel {
    if (!isAvailable.value) {
      return "Standard Build";
    }
    final patch = currentPatch.value;
    if (patch != null) {
      return "Patch #${patch.number}";
    }
    return "Base release";
  }

  /// Initialize service on app start.
  /// Runs silently in the background without blocking the UI.
  Future<void> init() async {
    try {
      isAvailable.value = _updater.isAvailable;
      debugPrint("🐦 [ShorebirdService] isAvailable: ${isAvailable.value}");

      if (!isAvailable.value) {
        return;
      }

      await _refreshPatchInfo();

      // Defer background update check by 4 seconds so startup requests finish first
      Timer(const Duration(seconds: 4), () {
        checkForUpdateInBackground();
      });
    } catch (e) {
      debugPrint("⚠️ [ShorebirdService] init error: $e");
    }
  }

  /// Refreshes current and next patch metadata
  Future<void> _refreshPatchInfo() async {
    if (!isAvailable.value) return;
    try {
      currentPatch.value = await _updater.readCurrentPatch();
      nextPatch.value = await _updater.readNextPatch();

      if (nextPatch.value != null &&
          currentPatch.value?.number != nextPatch.value?.number) {
        hasPendingRestart.value = true;
      }
    } catch (e) {
      debugPrint("⚠️ [ShorebirdService] error reading patch info: $e");
    }
  }

  /// Background silent check and auto-download
  Future<void> checkForUpdateInBackground() async {
    if (!isAvailable.value || isChecking.value || isDownloading.value) return;

    try {
      isChecking.value = true;
      final status = await _updater.checkForUpdate();
      isChecking.value = false;

      debugPrint("🐦 [ShorebirdService] Background check status: $status");

      if (status == UpdateStatus.outdated) {
        isDownloading.value = true;
        await _updater.update();
        isDownloading.value = false;

        hasPendingRestart.value = true;
        await _refreshPatchInfo();

        _notifyUserRestartAvailable();
      } else if (status == UpdateStatus.restartRequired) {
        hasPendingRestart.value = true;
        await _refreshPatchInfo();
        _notifyUserRestartAvailable();
      }
    } catch (e) {
      isChecking.value = false;
      isDownloading.value = false;
      debugPrint("⚠️ [ShorebirdService] Background update check error: $e");
    }
  }

  /// Manual check triggered by user (e.g., from Account Settings)
  Future<void> checkForUpdateManual({bool notifyIfLatest = true}) async {
    if (!isAvailable.value) {
      showAppSnackbar(
        "Shorebird Updates",
        "Over-the-air code push is active in production builds.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (isChecking.value || isDownloading.value) {
      showAppSnackbar(
        "Checking for Updates",
        "An update check is already in progress...",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      isChecking.value = true;
      showAppSnackbar(
        "Checking for Updates",
        "Connecting to Shorebird...",
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      final status = await _updater.checkForUpdate();
      isChecking.value = false;

      await _refreshPatchInfo();

      switch (status) {
        case UpdateStatus.outdated:
          isDownloading.value = true;
          showAppSnackbar(
            "Downloading Update",
            "A new patch is available and downloading...",
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 3),
          );

          await _updater.update();
          isDownloading.value = false;
          hasPendingRestart.value = true;
          await _refreshPatchInfo();

          _showRestartDialog();
          break;

        case UpdateStatus.restartRequired:
          hasPendingRestart.value = true;
          _showRestartDialog();
          break;

        case UpdateStatus.upToDate:
          if (notifyIfLatest) {
            final patchText = currentPatch.value != null
                ? " (Patch #${currentPatch.value!.number})"
                : "";
            showAppSnackbar(
              "Up to Date",
              "You are on the latest version$patchText.",
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 3),
            );
          }
          break;

        case UpdateStatus.unavailable:
          showAppSnackbar(
            "Update Status",
            "Update service is currently unavailable.",
            snackPosition: SnackPosition.BOTTOM,
          );
          break;
      }
    } catch (e) {
      isChecking.value = false;
      isDownloading.value = false;
      debugPrint("⚠️ [ShorebirdService] Manual check error: $e");
      showAppSnackbar(
        "Update Check Failed",
        "Could not reach update server. Please check your internet connection.",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Gentle banner/toast informing the user that an update has finished downloading
  void _notifyUserRestartAvailable() {
    showAppSnackbar(
      "Update Ready",
      "A new update has been downloaded. Restart the app anytime to apply it.",
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
  }

  /// Optional prompt dialog asking user if they want to restart or keep browsing
  void _showRestartDialog() {
    if (Get.context == null) return;

    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF161622),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B9BFF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Color(0xFF8B9BFF),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Update Downloaded",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "The latest update has been installed successfully. Please restart the app to apply the newest features.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B9BFF),
                    foregroundColor: const Color(0xFF0F0B1E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Got It",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
