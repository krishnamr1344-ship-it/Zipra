import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy'), backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms of Service', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
            const SizedBox(height: 8),
            Text('Welcome to Zipra.\n\n'
                'By accessing or using Zipra, you agree to comply with these Terms of Service. '
                'Zipra provides a platform for ordering groceries and daily essentials for delivery to your location.\n\n'
                'Users are responsible for providing accurate account information, delivery addresses, and payment details. '
                'Any misuse of the platform, fraudulent activity, or violation of applicable laws may result in '
                'suspension or termination of access.\n\n'
                'Product availability, prices, offers, and delivery times may change without prior notice. '
                'While we strive to provide accurate information, occasional errors may occur, and Zipra reserves '
                'the right to correct them when necessary.\n\n'
                'By continuing to use our services, you acknowledge and agree to these terms and any future updates.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
            const SizedBox(height: 30),
            const Text('Privacy Policy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
            const SizedBox(height: 8),
            Text('Your privacy is important to us.\n\n'
                'Zipra collects information such as your name, phone number, email address, delivery address, '
                'and order history to provide and improve our services.\n\n'
                'This information is used to process orders, facilitate deliveries, provide customer support, '
                'send important service updates, and enhance your overall experience within the app.\n\n'
                'We do not sell your personal information to third parties. Your data is stored securely and '
                'accessed only when necessary to operate our services. We may share limited information with '
                'trusted delivery and payment partners solely for order fulfillment purposes.\n\n'
                'By using Zipra, you consent to the collection and use of your information as described in '
                'this Privacy Policy.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
