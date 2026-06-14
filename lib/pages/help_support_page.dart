import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/theme.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  void _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
        debugPrint("pages.help_support_page: $e");}
  }

  void _email(String address) async {
    final uri = Uri.parse('mailto:$address');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
        debugPrint("pages.help_support_page: $e");}
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
        debugPrint("pages.help_support_page: $e");}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.appBarGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Frequently Asked Questions'),
          const SizedBox(height: 12),
          _faqTile('How do I place an order?',
              'Browse products, add items to your cart, proceed to checkout, enter your delivery address, and confirm your order.'),
          _faqTile('What payment methods are accepted?',
              'We currently accept Cash on Delivery (COD). More payment options coming soon.'),
          _faqTile('How long does delivery take?',
              'Delivery typically takes 1-3 business days within our serviceable areas.'),
          _faqTile('Can I cancel my order?',
              'Yes, you can cancel your order from the My Orders page as long as it has not been shipped.'),
          _faqTile('What is your return policy?',
              'If you receive a damaged or incorrect item, contact us within 48 hours for a replacement or refund.'),
          _faqTile('How do I update my delivery address?',
              'Go to Account > Addresses to add or update your delivery addresses.'),
          const SizedBox(height: 24),
          _section('Contact Us'),
          const SizedBox(height: 12),
          _contactTile(Icons.phone, 'Call Us', '+91 98765 43210',
              'Mon-Sat, 9 AM - 8 PM', () => _call('+919876543210')),
          _contactTile(Icons.email, 'Email Us', 'support@deliveryapp.com',
              'We reply within 24 hours', () => _email('support@deliveryapp.com')),
          _contactTile(Icons.chat, 'Live Chat', 'Available 9 AM - 6 PM',
              'Chat with our support team', () {}),
          const SizedBox(height: 24),
          _section('Other Resources'),
          const SizedBox(height: 12),
          _navTile(Icons.article_outlined, 'Terms & Conditions', 'Read our T&C',
              () => _openUrl('https://deliveryapp.com/terms')),
          _navTile(Icons.privacy_tip_outlined, 'Privacy Policy', 'How we handle your data',
              () => _openUrl('https://deliveryapp.com/privacy')),
          _navTile(Icons.info_outline, 'About Us', 'Learn about our service',
              () => _openUrl('https://deliveryapp.com/about')),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }

  Widget _faqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        children: [
          Text(answer, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  Widget _contactTile(IconData icon, String title, String value, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
      ),
    );
  }

  Widget _navTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
      ),
    );
  }
}