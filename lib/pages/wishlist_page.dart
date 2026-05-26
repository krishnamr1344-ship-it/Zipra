import 'package:flutter/material.dart';
import '../models/cart_model.dart';

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
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_outline, size: 80, color: Color(0xFFBDBDBD)),
                  SizedBox(height: 16),
                  Text('Your wishlist is empty', style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E))),
                ],
              ),
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
