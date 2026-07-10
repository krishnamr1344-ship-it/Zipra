import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import '../models/cart_model.dart';
import '../models/grocery_product.dart';
import '../widgets/product_grid.dart';
import 'login_page.dart';
import 'cart_page.dart';
import 'wishlist_page.dart';
import 'help_support_page.dart';
import 'settings_page.dart';
import 'product_detail_page.dart';
import 'orders_page.dart';
import 'location_picker_sheet.dart';
import 'map_picker_page.dart';
import 'addresses_page.dart';
import 'payments_page.dart';
import 'suggest_products_page.dart';
import 'edit_profile_page.dart';
import 'offers_page.dart';

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
  bool _isLoggedIn = false;

  List<Map<String, dynamic>> _offers = [];
  final _searchCtl = TextEditingController();
  String _searchQuery = '';

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco;
      case 'dairy':
        return Icons.water_drop;
      case 'bakery':
        return Icons.bakery_dining;
      case 'beverages':
        return Icons.local_cafe;
      case 'snacks':
        return Icons.cookie;
      case 'meat & fish':
        return Icons.set_meal;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadData();
    _loadGpsAddress();
    orderNotifier.init();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final token = await _api.getToken();
    if (mounted) setState(() => _isLoggedIn = token != null);
    if (token != null) _loadProfile();
  }

  Future<void> _loadGpsAddress() async {
    final addr = await LocationService.getSavedGpsAddress();
    if (addr['address_line1'] != null && addr['address_line1']!.isNotEmpty) {
      final line1 = addr['address_line1']!;
      final line2 = addr['address_line2'] ?? '';
      final city = addr['city'] ?? '';
      setState(() {
        _locationArea = line2.isNotEmpty
            ? '$line2, $city'
            : city.isNotEmpty
            ? city
            : 'Your Area';
        _locationDetail = line1;
      });
      final lat = double.tryParse(addr['latitude'] ?? '');
      final lng = double.tryParse(addr['longitude'] ?? '');
      if (lat != null && lng != null) {
        final result = await DeliveryZoneService().checkLocation(lat, lng);
        if (!mounted) return;
        setState(() {
          _serviceable = result.serviceable;
          _zoneChecked = true;
        });
      }
    } else {
      _detectCurrentLocation();
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _locationArea = 'Detecting...';
      _locationDetail = '';
    });
    final loc = await LocationService().getCurrentLocation();
    if (!mounted) return;
    if (loc.error != null) {
      setState(() {
        _locationArea = 'Your Area';
        _locationDetail = '';
        _zoneChecked = true;
      });
      return;
    }
    try {
      final resp = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=${loc.latitude}&lon=${loc.longitude}&format=json&addressdetails=1',
        ),
        headers: {'User-Agent': 'DeliveryApp/1.0'},
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final a = data['address'] as Map<String, dynamic>?;
        if (a != null) {
          final road = a['road'] ?? '';
          final house = a['house_number'] ?? '';
          final area_raw = a['suburb'] ?? a['city_district'] ?? '';
          final area = area_raw
              .replaceAll(RegExp(r'^Zone\s+\d+\s*', caseSensitive: false), '')
              .trim();
          final city_raw =
              a['city'] ?? a['town'] ?? a['village'] ?? a['county'] ?? '';
          final city = city_raw
              .replaceAll(
                RegExp(
                  r'\s+(Corporation|Municipal|Municipality|Municipal\s+Corporation)\s*$',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
          final parts = <String>[];
          if (road.isNotEmpty) parts.add(road);
          if (house.isNotEmpty) parts.add(house);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'gps_address_line',
            parts.isNotEmpty ? parts.join(', ') : (data['display_name'] ?? ''),
          );
          await prefs.setString(
            'gps_address_line2',
            area.isNotEmpty && city.isNotEmpty ? '$area, $city' : area,
          );
          await prefs.setString('gps_city', city);
          await prefs.setString('gps_latitude', '${loc.latitude}');
          await prefs.setString('gps_longitude', '${loc.longitude}');
          if (mounted)
            setState(() {
              _locationArea = area.isNotEmpty && city.isNotEmpty
                  ? '$area, $city'
                  : city.isNotEmpty
                  ? city
                  : 'Your Area';
              _locationDetail = parts.isNotEmpty
                  ? parts.join(', ')
                  : (data['display_name'] ?? '');
            });
        }
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _locationArea = 'Your Area';
          _locationDetail = '';
        });
    }
    if (mounted) setState(() => _zoneChecked = true);
  }

  List<String> _extractImages(dynamic images) {
    if (images is! List) return [];
    final urls = <String>[];
    for (final item in images) {
      if (item is String) {
        urls.add(item);
      } else if (item is Map) {
        final url = item['image_url'] ?? item['url'] ?? item['src'];
        if (url is String && url.isNotEmpty) urls.add(url);
      }
    }
    return urls;
  }

  List<_ProductData> get _filteredProducts {
    var source = _allProducts;
    if (_selectedCategory != 'All')
      source = source.where((p) => p['category_name'] == _selectedCategory).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      source = source.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final cat = (p['category_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }
    return source
        .map(
          (p) => _ProductData(
            p['id'] ?? '',
            _catIcon(p['category_name'] ?? ''),
            p['name'] ?? '',
            (p['price'] ?? 0).toInt(),
            p['unit'] ?? '',
            p['category_name'] ?? '',
            _extractImages(p['images']),
          ),
        )
        .toList();
  }

  Future<void> _loadData() async {
    setState(() => _loadingProducts = true);
    try {
      final cats = await _api.getCategories();
      final prods = await _api.getProducts();
      _offers = (await _api.getOffers()).cast<Map<String, dynamic>>();
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

  Future<bool> _requireLogin() async {
    final token = await _api.getToken();
    if (token != null) return true;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return loggedIn == true;
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
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const MapPickerPage()),
      );
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
      const OffersPage(),
      const CartPage(),
      _buildAccount(initial, name),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) async {
            if (i >= 3) {
              final token = await _api.getToken();
              if (token == null) {
                final loggedIn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (loggedIn != true) return;
                await _loadProfile();
              }
            }
            setState(() => _selectedIndex = i);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 0 ? Icons.home_filled : Icons.home_outlined,
              ),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 2
                    ? Icons.local_offer
                    : Icons.local_offer_outlined,
              ),
              label: 'Offers',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 3
                    ? Icons.shopping_cart
                    : Icons.shopping_cart_outlined,
              ),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                _selectedIndex == 4 ? Icons.person : Icons.person_outline,
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String initial, String name) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
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
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _showLocationPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.white,
                          ),
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
                                    child: Text(
                                      _locationArea,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'HOME',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_locationDetail.isNotEmpty)
                                Text(
                                  _locationDetail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withAlpha(180),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: Colors.white70,
                          ),
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
                      icon: const Icon(
                        Icons.favorite_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WishlistPage()),
                      ),
                    ),
                    if (wishlistNotifier.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${wishlistNotifier.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() => _selectedIndex = 3);
                      },
                    ),
                    if (cartNotifier.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cartNotifier.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _searchCtl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.tune, color: Colors.white, size: 20),
              ),
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
                label: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                backgroundColor: AppColors.chipBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide.none,
                ),
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
          const Text(
            'Shop by Category',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (cats.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Text(
                  'No categories available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cats.map((cat) {
                final catProducts = _allProducts.where((p) => p['category_name'] == cat).toList();
                final imageUrl = catProducts.isNotEmpty
                    ? _extractImages(catProducts.first['images']).isNotEmpty
                        ? _extractImages(catProducts.first['images'])[0]
                        : null
                    : null;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedIndex = 0;
                    });
                  },
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 80,
                            child: imageUrl != null
                                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
                                : const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
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

  Widget _catFallback(String cat) {
    return Container(
      color: AppColors.chipBg,
      child: Center(child: Icon(_catIcon(cat), size: 36, color: AppColors.primary)),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'Login to Browse Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to view our full catalog and start ordering.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final loggedIn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (loggedIn == true) {
                  _loadProfile();
                  _loadData();
                  if (mounted) setState(() {});
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Login Now',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkLogin() async {
    return await _api.getToken() != null;
  }

  Widget _buildProductSection() {
    final products = _filteredProducts;

    return ListenableBuilder(
      listenable: Listenable.merge([cartNotifier, wishlistNotifier]),
      builder: (_, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_offers.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    itemCount: _offers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final o = _offers[i];
                      return Container(
                        width: MediaQuery.of(context).size.width * 0.7,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B00), Color(0xFFFF8C38)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.local_offer,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (o['description'] != null)
                                    Text(
                                      o['description'],
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(200),
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${o['discount_percent']}% OFF',
                                style: const TextStyle(
                                  color: Color(0xFFFF6B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedCategory == 'All'
                        ? 'Featured Products'
                        : _selectedCategory,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${products.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                      const Text(
                        'Coming Soon!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Delivery service is not yet available in your area.\nWe are expanding soon!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
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
                  child: Center(
                    child: Text(
                      'No products in this category',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ProductGrid(
                  products: products.map((p) => _toGroceryProduct(p)).toList(),
                  cartMap: {
                    for (final p in products)
                      p.id.hashCode: cartNotifier.items.any(
                        (e) => e.name == p.name,
                      ),
                  },
                  favMap: {
                    for (final p in products)
                      p.name: wishlistNotifier.contains(p.name),
                  },
                  getQuantity: (name) =>
                      cartNotifier.items
                          .where((e) => e.name == name)
                          .firstOrNull
                          ?.count ??
                      0,
                  getImages: (gp) {
                    final p = products.firstWhere((e) => e.name == gp.name);
                    return p.images;
                  },
                  onAdd: (gp) async {
                    final p = products.firstWhere((e) => e.name == gp.name);
                    if (!await _requireLogin()) return;
                    if (!mounted) return;
                    cartNotifier.add(
                      CartItem(
                        name: p.name,
                        qty: p.qty,
                        price: p.price,
                        icon: p.icon,
                        color: AppColors.success,
                        productId: p.id,
                        imageUrl: p.images.isNotEmpty ? p.images[0] : '',
                      ),
                    );
                  },
                  onIncrement: (gp) {
                    final p = products.firstWhere((e) => e.name == gp.name);
                    cartNotifier.updateCount(p.name, 1);
                  },
                  onDecrement: (gp) {
                    final p = products.firstWhere((e) => e.name == gp.name);
                    cartNotifier.updateCount(p.name, -1);
                  },
                  onFav: (gp) => wishlistNotifier.toggle(gp.name),
                  onTap: (gp) {
                    final p = products.firstWhere((e) => e.name == gp.name);
                    final count =
                        cartNotifier.items
                            .where((e) => e.name == p.name)
                            .firstOrNull
                            ?.count ??
                        0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          icon: p.icon,
                          color: AppColors.success,
                          name: p.name,
                          price: p.price,
                          qty: p.qty,
                          images: p.images,
                          inCart: count > 0,
                          onAdd: (qty) async {
                            if (!await _requireLogin()) return;
                            if (!mounted) return;
                            final existing = cartNotifier.items.where((e) => e.name == p.name).firstOrNull;
                            if (existing != null) {
                              cartNotifier.updateCount(p.name, qty);
                            } else {
                              cartNotifier.add(CartItem(
                                name: p.name,
                                qty: p.qty,
                                price: p.price,
                                icon: p.icon,
                                color: AppColors.success,
                                productId: p.id,
                                imageUrl: p.images.isNotEmpty ? p.images[0] : '',
                                count: qty,
                              ));
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
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
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: CircleAvatar(
                  radius: avatarR,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: avatarR * 0.8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfilePage(user: _user ?? {}),
                    ),
                  );
                  if (result != null) {
                    _loadProfile();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _menuCard([
                _menuItem(
                  Icons.receipt_long_outlined,
                  'My Orders',
                  'View order history',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersPage()),
                  ),
                ),
                _menuItem(
                  Icons.location_on_outlined,
                  'Addresses',
                  'Manage delivery addresses',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesPage()),
                  ),
                ),
                _menuItem(
                  Icons.credit_card_outlined,
                  'Payments',
                  'Saved cards & wallets',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaymentsPage()),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'OTHER INFORMATION',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHint,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _menuCard([
                _menuItem(
                  Icons.feedback_outlined,
                  'Suggest Products',
                  'Tell us what you need',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SuggestProductsPage(),
                    ),
                  ),
                ),
                _menuItem(
                  Icons.notifications_outlined,
                  'Notifications',
                  'Manage alerts & updates',
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  ),
                ),
                _menuItem(
                  Icons.favorite,
                  'Favorites',
                  '${wishlistNotifier.itemCount} items',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WishlistPage()),
                  ),
                ),
                _menuItem(
                  Icons.support_outlined,
                  'Help & Support',
                  'FAQs & contact',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _menuCard([
                _menuItem(
                  Icons.settings_outlined,
                  'Settings',
                  'App preferences',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
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
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF5F5),
                      foregroundColor: const Color(0xFFF44336),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 20,
            ),
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
  const _ProductData(
    this.id,
    this.icon,
    this.name,
    this.price,
    this.qty,
    this.category,
    this.images,
  );
}

String _emojiFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('rice')) return '🍚';
  if (n.contains('milk') ||
      n.contains('curd') ||
      n.contains('paneer') ||
      n.contains('cheese') ||
      n.contains('butter') ||
      n.contains('ghee'))
    return '🥛';
  if (n.contains('coffee') ||
      n.contains('boost') ||
      n.contains('horlicks') ||
      n.contains('tea'))
    return '☕';
  if (n.contains('biscuit') || n.contains('cookie')) return '🍪';
  if (n.contains('chip') || n.contains('popcorn') || n.contains('noodle'))
    return '🍿';
  if (n.contains('banana') || n.contains('apple') || n.contains('fruit'))
    return '🍌';
  if (n.contains('notebook') || n.contains('pen') || n.contains('pencil'))
    return '📝';
  return '🛒';
}

Color _colorFor(String category) {
  final c = category.toLowerCase();
  if (c.contains('rice')) return const Color(0xFFEFF6FF);
  if (c.contains('dairy')) return const Color(0xFFF0FDF4);
  if (c.contains('beverage')) return const Color(0xFFFFF3EA);
  if (c.contains('snack')) return const Color(0xFFFFFBEB);
  if (c.contains('stationery')) return const Color(0xFFF5F3FF);
  return const Color(0xFFFFF3EA);
}

GroceryProduct _toGroceryProduct(_ProductData p) {
  return GroceryProduct(
    id: p.id.hashCode,
    name: p.name,
    weight: p.qty,
    price: p.price.toDouble(),
    emoji: _emojiFor(p.name),
    imageBg: _colorFor(p.category),
  );
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
    child: Text(
      letter.toUpperCase(),
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: color.withAlpha(180),
      ),
    ),
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
    final color = AppColors.success;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withAlpha(20), color.withAlpha(40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: images.isNotEmpty && images[0].startsWith('http')
                        ? Image.network(
                            images[0],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(name[0], color),
                          )
                        : _placeholder(name[0], color),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onFav,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFav ? Colors.red : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                  if (inCart)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'In Cart',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 22,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          '$price',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: inCart
                              ? color.withValues(alpha: 0.12)
                              : color,
                          foregroundColor: inCart ? color : Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(inCart ? Icons.check : Icons.add, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              inCart ? 'Added' : 'Add',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
