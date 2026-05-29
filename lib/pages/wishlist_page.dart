import 'package:flutter/material.dart';
import '../models/cart_model.dart';
import '../widgets/state_widgets.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wishlistNotifier,
      builder: (_, _) {
        if (wishlistNotifier.items.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wishlist')),
            body: const EmptyStateWidget(
              icon: Icons.favorite_outline,
              title: 'Your wishlist is empty',
              subtitle: 'Save items you love',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Wishlist')),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wishlistNotifier.items.length,
            itemBuilder: (_, i) {
              final name = wishlistNotifier.items.elementAt(i);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.red),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFBDBDBD)),
                    onPressed: () => wishlistNotifier.toggle(name),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
