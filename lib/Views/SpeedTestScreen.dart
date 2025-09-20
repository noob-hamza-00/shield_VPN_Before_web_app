import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

// Custom painter for Ookla-style meter gauge
class _MeterGaugePainter extends CustomPainter {
  final double value;
  final double maxValue;
  final Color color;
  final String label;
  _MeterGaugePainter({required this.value, required this.maxValue, required this.color, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;
    final startAngle = pi * 0.75;
    final sweepAngle = pi * 1.5;
    final bgPaint = Paint()
      ..color = Colors.grey.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    final arcPaint = Paint()
      ..shader = LinearGradient(colors: [color.withOpacity(0.7), color.withOpacity(0.3)])
          .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
      
    // Draw background arc
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, bgPaint);
    // Draw value arc
    double valueSweep = sweepAngle * (value / maxValue).clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, valueSweep, false, arcPaint);

    // Draw ticks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    for (int i = 0; i <= 10; i++) {
      double tickAngle = startAngle + sweepAngle * (i / 10);
      final tickStart = Offset(
        center.dx + (radius - 10) * cos(tickAngle),
        center.dy + (radius - 10) * sin(tickAngle),
      );
      final tickEnd = Offset(
        center.dx + (radius + 10) * cos(tickAngle),
        center.dy + (radius + 10) * sin(tickAngle),
      );
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }

    // Draw needle
    final needleAngle = startAngle + valueSweep;
    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    final needleEnd = Offset(
      center.dx + (radius - 8) * cos(needleAngle),
      center.dy + (radius - 8) * sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 8, Paint()..color = color.withOpacity(0.7));
  }



  @override
  bool shouldRepaint(covariant _MeterGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({Key? key}) : super(key: key);

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  // No local speed test variables needed

  Future<void> _startSpeedTest() async {
    // Open speedtest.net in browser
    final url = Uri.parse('https://www.speedtest.net/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open speedtest.net')),
      );
    }
  }

  Widget _buildMeterGauge({required double value, required double maxValue, required Color color, required String label, required IconData icon, required bool loading}) {
    // Show static meters with 0 Mbps
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              painter: _MeterGaugePainter(
                value: 0.0,
                maxValue: maxValue,
                color: color,
                label: label,
              ),
              child: SizedBox(
                width: 140,
                height: 140,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Icon(icon, color: color, size: 28),
        SizedBox(height: 4),
        Text(
          '0.00 Mbps',
          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with a simple white back arrow
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('Internet Speed Test', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMeterGauge(
                  value: 0.0,
                  maxValue: 100,
                  color: Colors.blueAccent,
                  label: 'Download',
                  icon: Icons.arrow_downward,
                  loading: false,
                ),
                SizedBox(width: 32),
                _buildMeterGauge(
                  value: 0.0,
                  maxValue: 100,
                  color: Colors.pinkAccent,
                  label: 'Upload',
                  icon: Icons.arrow_upward,
                  loading: false,
                ),
              ],
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _startSpeedTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Start Test', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}


