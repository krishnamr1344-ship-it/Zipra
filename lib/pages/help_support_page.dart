import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: const Center(child: Text('FAQs & contact info coming soon', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16))),
    );
  }
}
