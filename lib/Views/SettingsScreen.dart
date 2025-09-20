import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoReconnect = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() { _autoReconnect = prefs.getBool('auto_reconnect_on_reopen') ?? true; });
    } catch (_) {}
  }

  Future<void> _setAutoReconnect(bool value) async {
    setState(() { _autoReconnect = value; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_reconnect_on_reopen', value);
    } catch (_) {}
  }
  void _shareApp(BuildContext context) {
    Share.share(
      'Download Shield VPN: https://play.google.com/store/apps/details?id=com.technosofts.vpnmax',
      subject: 'Shield VPN - Fast & Secure VPN',
    );
  }

  Future<void> _sendFeedback() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'vpnapp@technosofts.net',
      query: 'subject=VPN App Feedback&body=Write your feedback here',
    );
    await launchUrl(emailLaunchUri);
  }

  Future<void> _rateUs() async {
    const url = 'https://play.google.com/store/apps/dev?id=6375425433809003607';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: _autoReconnect,
              onChanged: _setAutoReconnect,
              title: const Text('Auto reconnect on reopen', style: TextStyle(color: Colors.white, fontSize: 18)),
              subtitle: const Text('If the VPN was connected before and the app was closed, reconnect automatically on reopen', style: TextStyle(color: Colors.white70)),
              activeColor: Colors.greenAccent,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.feedback, color: Colors.red, size: 28),
              title: const Text('Send Feedback', style: TextStyle(color: Colors.white, fontSize: 18)),
              subtitle: const Text('Let us know your thoughts', style: TextStyle(color: Colors.white70)),
              onTap: _sendFeedback,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.star_rate, color: Colors.amber, size: 28),
              title: const Text('Rate Us', style: TextStyle(color: Colors.white, fontSize: 18)),
              subtitle: const Text('Rate us on Play Store', style: TextStyle(color: Colors.white70)),
              onTap: _rateUs,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blueAccent, size: 28),
              title: const Text('Share App', style: TextStyle(color: Colors.white, fontSize: 18)),
              subtitle: const Text('Share Shield VPN with friends', style: TextStyle(color: Colors.white70)),
              onTap: () => _shareApp(context),
            ),
          ],
        ),
      ),
    );
  }
}
