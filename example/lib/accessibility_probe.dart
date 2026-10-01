import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app_privacy/mobile_app_privacy.dart';

void main() => runApp(const MaterialApp(home: AccessibilityProbe()));

class AccessibilityProbe extends StatefulWidget {
  const AccessibilityProbe({super.key});

  @override
  State<AccessibilityProbe> createState() => _AccessibilityProbeState();
}

class _AccessibilityProbeState extends State<AccessibilityProbe> {
  final privacy = MobileAppPrivacy();
  final controller = TextEditingController(text: 'private-probe-0');
  Timer? timer;
  int count = 0;
  String status = 'loading';

  @override
  void initState() {
    super.initState();
    refresh();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      controller.text = 'private-probe-${++count}';
    });
  }

  Future<void> refresh() async {
    final filtered = await privacy.isAccessibilityDataSensitive();
    if (mounted) setState(() => status = 'filtered=$filtered');
  }

  Future<void> setProtection(bool enabled) async {
    await privacy.setAccessibilityDataSensitive(enabled);
    await refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const Text('public-probe'),
          Text(status),
          const Text('seed-probe'),
          TextField(controller: controller, autofocus: true),
          const AccessibilitySensitive(child: Text('fallback-probe')),
          TextButton(
            onPressed: () => setProtection(false),
            child: const Text('Disable protection'),
          ),
          TextButton(
            onPressed: () => setProtection(true),
            child: const Text('Enable protection'),
          ),
        ],
      ),
    ),
  );
}
