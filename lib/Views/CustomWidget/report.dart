// Removed unused math import to satisfy analyzer
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vpn_app/Views/Constant.dart';

/// Popup session report with translucent blurred background.
/// Call SessionReport.show(...) to display after disconnect.
class SessionReport extends StatelessWidget {
  final String serverName;
  final Duration duration;
  final double avgDownloadMbps;
  final double avgUploadMbps;
  final double lastDownloadMbps;
  final double lastUploadMbps;
  final int pingMs;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<double> downloadSamples;
  final List<double> uploadSamples;
  final String? serverFlagAsset; // optional flag path

  const SessionReport({
    super.key,
    required this.serverName,
    required this.duration,
    required this.avgDownloadMbps,
    required this.avgUploadMbps,
    required this.lastDownloadMbps,
    required this.lastUploadMbps,
    required this.pingMs,
    required this.startedAt,
    required this.endedAt,
    this.downloadSamples = const [],
    this.uploadSamples = const [],
    this.serverFlagAsset,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  // (Removed max sample usage; kept math import for potential future metrics)

  @override
  Widget build(BuildContext context) {
    // Build a concise, non-scrollable, text-only summary popup.
    final durationStr = _formatDuration(duration);
    final startStr = startedAt.toLocal().toString().substring(11,19);
    final endStr = endedAt.toLocal().toString().substring(11,19);
    final avgDownStr = avgDownloadMbps.toStringAsFixed(2);
    final avgUpStr = avgUploadMbps.toStringAsFixed(2);
    final lastDownStr = lastDownloadMbps.toStringAsFixed(2);
    final lastUpStr = lastUploadMbps.toStringAsFixed(2);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session Report', style: boldStyle.copyWith(fontSize: 18))
              .animate().fadeIn(duration: 280.ms).slideY(begin: 0.25),
          const SizedBox(height: 10),
          _line('Server', serverName, 0),
          _line('Duration', durationStr, 40),
          _line('Ping', '$pingMs ms', 70),
          _line('Start', startStr, 100),
          _line('End', endStr, 130),
          const Divider(height: 22, thickness: 0.7, color: Colors.white24),
          _line('Avg Download', '$avgDownStr Mbps', 160),
          _line('Avg Upload', '$avgUpStr Mbps', 190),
          _line('Last Download', '$lastDownStr Mbps', 220),
          _line('Last Upload', '$lastUpStr Mbps', 250),
      const SizedBox(height: 20),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                foregroundColor: Colors.white,
                backgroundColor: blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.8),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.92,0.92)),
          ),
        ],
      ),
    );

    final screenH = MediaQuery.of(context).size.height;
    final maxPopupHeight = screenH * 0.72; // scale with screen
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxPopupHeight.clamp(360.0, 480.0)),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.48),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: content,
              ),
            ),
          ).animate().fadeIn(duration: 280.ms).scale(begin: const Offset(0.92,0.92), curve: Curves.easeOutCubic),
        ),
      ),
    );
  }

  /// Helper to show the popup dialog with background blur & dim.
  static Future<void> show(
    BuildContext context, {
    required String serverName,
    required Duration duration,
    required double avgDownloadMbps,
    required double avgUploadMbps,
    required double lastDownloadMbps,
    required double lastUploadMbps,
    required int pingMs,
    required DateTime startedAt,
    required DateTime endedAt,
    List<double> downloadSamples = const [],
    List<double> uploadSamples = const [],
    String? serverFlagAsset,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Session Report',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) {
        return Stack(
          children: [
            // Dim + global blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
            SessionReport(
              serverName: serverName,
              duration: duration,
              avgDownloadMbps: avgDownloadMbps,
              avgUploadMbps: avgUploadMbps,
              lastDownloadMbps: lastDownloadMbps,
              lastUploadMbps: lastUploadMbps,
              pingMs: pingMs,
              startedAt: startedAt,
              endedAt: endedAt,
              downloadSamples: downloadSamples,
              uploadSamples: uploadSamples,
              serverFlagAsset: serverFlagAsset,
            ),
          ],
        );
      },
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
  }
}

// Helper to build each animated line (label : value)
  Widget _line(String label, String value, int delayMs) {
    final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: mediumStyle.copyWith(fontSize: 12, color: Colors.white60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: boldStyle.copyWith(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: row
          .animate()
          .fadeIn(delay: Duration(milliseconds: delayMs), duration: 260.ms)
          .slideX(begin: 0.18, end: 0, curve: Curves.easeOut),
    );
  }
