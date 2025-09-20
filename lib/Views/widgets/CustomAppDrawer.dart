import 'package:flutter/material.dart';
import 'package:vpn_app/Views/Constant.dart';
import 'package:vpn_app/Views/PremiumScreen.dart';

class CustomAppDrawer extends StatelessWidget {
  final VoidCallback onSpeedTest;
  final VoidCallback onLocations;

  const CustomAppDrawer({
    super.key,
    required this.onSpeedTest,
    required this.onLocations,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: primarycolor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Menu', style: boldStyle.copyWith(fontSize: 22)),
            ),
            const Divider(color: Colors.white24, height: 1),
            _DrawerItem(
              icon: Icons.speed,
              label: 'Speed Test',
              onTap: onSpeedTest,
            ),
            _DrawerItem(
              icon: Icons.location_on,
              label: 'Locations',
              onTap: onLocations,
            ),
              const Spacer(),
              ListTile(
                leading: Icon(Icons.workspace_premium, color: Colors.amberAccent),
                title: Text('Premium', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (context, animation, secondaryAnimation) => const PremiumScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                      return SlideTransition(position: offsetAnimation, child: child);
                    },
                  ));
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'VPN Shield',
                style: mediumStyle.copyWith(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardcolor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: blue, size: 20),
            ),
            const SizedBox(width: 12),
            Text(label, style: mediumStyle.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
