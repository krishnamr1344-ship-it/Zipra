import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import '../models/cart_model.dart';
import 'login_page.dart';
import 'cart_page.dart';
import 'wishlist_page.dart';
import 'help_support_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'product_detail_page.dart';
import 'orders_page.dart';
import 'location_picker_sheet.dart';
import 'map_picker_page.dart';
import 'addresses_page.dart';
import 'payments_page.dart';
import 'suggest_products_page.dart';
import 'edit_profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = ApiService();
  int _selectedIndex = 0;
  String _locationArea = '';
  String _locationDetail = '';
  String _selectedCategory = 'All';
  Map<String, dynamic>? _user;

  List<String> _categories = ['All'];
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = true;
  bool _serviceable = true;
  bool _zoneChecked = false;

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'fruits': return Icons.apple;
      case 'vegetables': return Icons.eco;
      case 'dairy': return Icons.water_drop;
      case 'bakery': return Icons.bakery_dining;
      case 'beverages': return Icons.local_cafe;
      case 'snacks': return Icons.cookie;
      case 'meat & fish': return Icons.set_meal;
      default: return Icons.shopping_bag;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadData();
    _loadGpsAddress();
    orderNotifier.init();
  }

  Future<void> _loadGpsAddress() async {
    final addr = await LocationService.getSavedGpsAddress();
    if (addr['address_line1'] != null && addr['address_line1']!.isNotEmpty) {
      final line1 = addr['address_line1']!;
      final line2 = addr['address_line2'] ?? '';
      final city = addr['city'] ?? '';
      setState(() {
        _locationArea = line2.isNotEmpty ? '$line2, $city' : city.isNotEmpty ? city : 'Your Area';
        _locationDetail = line1;
      });
      final lat = double.tryParse(addr['latitude'] ?? '');
      final lng = double.tryParse(addr['longitude'] ?? '');
      if (lat != null && lng != null) {
        final result = await DeliveryZoneService().checkLocation(lat, lng);
        if (!mounted) return;
        setState(() { _serviceable = result.serviceable; _zoneChecked = true; });
      }
    } else {
      setState(() { _locationArea = 'Your Area'; _locationDetail = ''; _zoneChecked = true; });
    }
  }

  List<_ProductData> get _filteredProducts {
    if (_selectedCategory == 'All') return _allProducts.map((p) => _ProductData(
      p['id'] ?? '',
      _catIcon(p['category_name'] ?? ''),
      p['name'] ?? '',
      (p['price'] ?? 0).toInt(),
      p['unit'] ?? '',
      p['category_name'] ?? '',
      p['images'] is List ? (p['images'] as List).cast<String>() : [],
    )).toList();
    return _allProducts.where((p) => p['category_name'] == _selectedCategory).map((p) => _ProductData(
      p['id'] ?? '',
      _catIcon(p['category_name'] ?? ''),
      p['name'] ?? '',
      (p['price'] ?? 0).toInt(),
      p['unit'] ?? '',
      p['category_name'] ?? '',
      p['images'] is List ? (p['images'] as List).cast<String>() : [],
    )).toList();
  }

  Future<void> _loadData() async {
    setState(() => _loadingProducts = true);
    try {
      final cats = await _api.getCategories();
      final prods = await _api.getProducts();
      if (!mounted) return;
      setState(() {
        _categories = ['All', ...cats.map<String>((c) => c['name'] as String)];
        _allProducts = prods.cast<Map<String, dynamic>>();
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
    }
  }

  Future<void> _loadProfile() async {
    final userData = await _api.getSavedUser();
    if (!mounted) return;
    setState(() => _user = userData);
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showLocationPicker() async {
    final openMap = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LocationPickerSheet(),
    );
    if (openMap == true) {
      final confirmed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const MapPickerPage()));
      if (confirmed == true) _loadGpsAddress();
    } else {
      _loadGpsAddress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['name'] ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final pages = [
      _buildHome(initial, name),
      _buildCategoriesTab(),
      _buildOffersTab(),
      const CartPage(),
      _buildAccount(initial, name),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF6C63FF),
              unselectedItemColor: const Color(0xFFBDBDBD),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              items: [
                BottomNavigationBarItem(icon: Icon(_selectedIndex == 0 ? Icons.home_filled : Icons.home_outlined), label: 'Home'),
                const BottomNavigationBarItem(icon: Icon(Icons.category_outlined), label: 'Categories'),
                BottomNavigationBarItem(icon: Icon(_selectedIndex == 2 ? Icons.local_offer : Icons.local_offer_outlined), label: 'Offers'),
                BottomNavigationBarItem(icon: Icon(_selectedIndex == 3 ? Icons.shopping_cart : Icons.shopping_cart_outlined), label: 'Cart'),
                BottomNavigationBarItem(icon: Icon(_selectedIndex == 4 ? Icons.person : Icons.person_outline), label: 'Account'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String initial, String name) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF483D8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  child: Text(initial, style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFF6C63FF).withAlpha(30), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.location_on, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(_locationArea, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('HOME', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                  ),
                                ],
                              ),
                              if (_locationDetail.isNotEmpty)
                                Text(_locationDetail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(180))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: wishlistNotifier,
                builder: (_, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_outline, color: Colors.white, size: 24),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage())),
                    ),
                    if (wishlistNotifier.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Text('${wishlistNotifier.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: cartNotifier,
                builder: (_, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 24), onPressed: () {
                      setState(() => _selectedIndex = 3);
                    }),
                    if (cartNotifier.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          child: Text('${cartNotifier.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: Color(0xFF6C63FF), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.tune, color: Colors.white, size: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(String initial, String name) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(initial, name),
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildProductSection(),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF2D2D3A))),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: const Color(0xFF6C63FF),
                checkmarkColor: Colors.white,
                backgroundColor: const Color(0xFFF5F5FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final cats = _categories.where((c) => c != 'All').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Shop by Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 20),
          if (cats.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Text('No categories available', style: TextStyle(color: Color(0xFF9E9E9E))),
            ))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cats.map((cat) {
                final icon = _catIcon(cat);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedIndex = 0;
                    });
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, size: 40, color: const Color(0xFF6C63FF)),
                        const SizedBox(height: 12),
                        Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProductSection() {
    final products = _filteredProducts;

    return ListenableBuilder(
      listenable: Listenable.merge([cartNotifier, wishlistNotifier]),
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedCategory == 'All' ? 'Featured Products' : _selectedCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 12),
            if (_zoneChecked && !_serviceable)
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withAlpha(40)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.orange.shade400),
                    const SizedBox(height: 12),
                    const Text('Coming Soon!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 6),
                    Text(
                      'Delivery service is not yet available in your area.\nWe are expanding soon!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                    ),
                  ],
                ),
              )
            else if (_loadingProducts)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text('No products in this category', style: TextStyle(color: Color(0xFF9E9E9E)))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  final count = cartNotifier.items.where((e) => e.name == p.name).firstOrNull?.count ?? 0;
                  final isFav = wishlistNotifier.contains(p.name);
                  return _ProductCard(
                    icon: p.icon, name: p.name, price: p.price, images: p.images,
                    isFav: isFav, inCart: count > 0,
                    onAdd: () {
                      cartNotifier.add(CartItem(name: p.name, qty: p.qty, price: p.price, icon: p.icon, color: const Color(0xFF4CAF50), productId: p.id));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} added'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFF4CAF50)));
                    },
                    onFav: () => wishlistNotifier.toggle(p.name),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(
                      icon: p.icon, color: const Color(0xFF4CAF50), name: p.name, price: p.price, qty: p.qty, images: p.images,
                      inCart: count > 0,
                      onAdd: () {
                        cartNotifier.add(CartItem(name: p.name, qty: p.qty, price: p.price, icon: p.icon, color: const Color(0xFF4CAF50), productId: p.id));
                      },
                    ))),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 80, color: const Color(0xFF6C63FF).withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          const Text('Coming Soon', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          const Text('Offers feature is under development', style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildAccount(String initial, String name) {
    final email = _user?['email'] ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final avatarR = (constraints.maxWidth * 0.12).clamp(42.0, 52.0);
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: (constraints.maxHeight * 0.06).clamp(30, 50)),
              CircleAvatar(
                radius: avatarR + 5,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                child: CircleAvatar(
                  radius: avatarR,
                  backgroundColor: const Color(0xFF6C63FF),
                  child: Text(initial, style: TextStyle(color: Colors.white, fontSize: avatarR * 0.8, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => EditProfilePage(user: _user ?? {})));
                  if (result != null) {
                    _loadProfile();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: Color(0xFF6C63FF)),
                      SizedBox(width: 4),
                      Text('Edit Profile', style: TextStyle(fontSize: 12, color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _menuCard([
                _menuItem(Icons.receipt_long_outlined, 'My Orders', 'View order history', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()))),
                _menuItem(Icons.location_on_outlined, 'Addresses', 'Manage delivery addresses', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage()))),
                _menuItem(Icons.credit_card_outlined, 'Payments', 'Saved cards & wallets', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsPage()))),
              ]),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('OTHER INFORMATION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBDBDBD), letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 8),
              _menuCard([
                _menuItem(Icons.feedback_outlined, 'Suggest Products', 'Tell us what you need', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestProductsPage()))),
                _menuItem(Icons.notifications_outlined, 'Notifications', 'Manage alerts & updates', () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon!'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)))),
                _menuItem(Icons.favorite, 'Favorites', '${wishlistNotifier.itemCount} items', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage()))),
                _menuItem(Icons.support_outlined, 'Help & Support', 'FAQs & contact', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()))),
              ]),
              const SizedBox(height: 16),
              _menuCard([
                _menuItem(Icons.settings_outlined, 'Settings', 'App preferences', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
                _menuItem(Icons.info_outline, 'About', 'Version 1.0.0', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()))),
              ]),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF5F5),
                      foregroundColor: const Color(0xFFF44336),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }


  Widget _menuCard(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF5F5FF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D3A))), Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD)))])),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProductData {
  final String id;
  final IconData icon;
  final String name;
  final int price;
  final String qty;
  final String category;
  final List<String> images;
  const _ProductData(this.id, this.icon, this.name, this.price, this.qty, this.category, this.images);
}

Widget _placeholder(String letter, Color color) {
  return Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withAlpha(40), color.withAlpha(10)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Text(letter.toUpperCase(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color.withAlpha(180))),
  );
}

class _ProductCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final int price;
  final List<String> images;
  final bool isFav;
  final bool inCart;
  final VoidCallback onAdd;
  final VoidCallback onFav;
  final VoidCallback onTap;

  const _ProductCard({
    required this.icon,
    required this.name,
    required this.price,
    required this.images,
    required this.isFav,
    required this.inCart,
    required this.onAdd,
    required this.onFav,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF4CAF50);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 65,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: images.isNotEmpty && images[0].startsWith('http')
                          ? Image.network(images[0], fit: BoxFit.cover, width: double.infinity, height: 65, errorBuilder: (_, __, ___) => _placeholder(name[0], color))
                          : _placeholder(name[0], color),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: onFav,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          child: Icon(isFav ? Icons.favorite : Icons.favorite_outline, size: 12, color: isFav ? Colors.red : const Color(0xFFBDBDBD)),
                        ),
                      ),
                    ),
                  ],
                ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text('₹$price', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 12)),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: inCart ? color.withValues(alpha: 0.15) : color,
                          foregroundColor: inCart ? color : Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(inCart ? 'Added' : 'Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
