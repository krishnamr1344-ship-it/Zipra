import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../services/notification_service.dart';
import 'notifications_page.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/delivery_zone_service.dart';
import '../models/cart_model.dart';
import '../models/grocery_product.dart';
import '../widgets/product_grid.dart';
import '../widgets/state_widgets.dart';
import '../widgets/app_snackbar.dart';
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
  bool _error = false;
  bool _serviceable = true;
  bool _zoneChecked = false;

  final _searchController = TextEditingController();

  static const _orange = Color(0xFFFF6B00);
  static const _orangeSecondary = Color(0xFFFF8F00);
  static const _bgWarm = Color(0xFFFFF8F3);

  static const _smartChips = [
    {'label': 'Breakfast', 'emoji': '\u{1F373}'},
    {'label': 'Fresh Juice', 'emoji': '\u{1F9C3}'},
    {'label': 'Dinner Kits', 'emoji': '\u{1F371}'},
    {'label': 'Quick Combos', 'emoji': '\u26A1'},
    {'label': 'Beverages', 'emoji': '\u2615'},
    {'label': 'Snacks', 'emoji': '\u{1F37F}'},
  ];

  static const _offerBanners = [
    {'title': 'Weekend Special', 'subtitle': 'Extra 20% off on all snacks', 'color': 0xFFFF6B00, 'emoji': '\u{1F6CD}\uFE0F'},
    {'title': 'Fresh Arrivals', 'subtitle': 'Farm-fresh fruits & vegetables', 'color': 0xFFFF8F00, 'emoji': '\u{1F353}\u{1F96C}'},
    {'title': 'Free Delivery', 'subtitle': 'On orders above \u20B9499', 'color': 0xFFE65100, 'emoji': '\u{1F69A}'},
    {'title': 'New Launch', 'subtitle': 'Premium dry fruits collection', 'color': 0xFFFF6B00, 'emoji': '\u{1F330}'},
  ];

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

  String _catEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'fruits': return '\u{1F34E}';
      case 'vegetables': return '\u{1F966}';
      case 'dairy': return '\u{1F95B}';
      case 'bakery': return '\u{1F35E}';
      case 'beverages': return '\u2615';
      case 'snacks': return '\u{1F36A}';
      case 'meat & fish': return '\u{1F969}';
      default: return '\u{1F6D2}';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadData();
    _loadGpsAddress();
    cartNotifier.load();
    wishlistNotifier.load();
    notificationService.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGpsAddress() async {
    final addr = await LocationService.getSavedGpsAddress();
    if (addr['address_line1'] != null && addr['address_line1']!.isNotEmpty) {
      final line1 = addr['address_line1']!;
      final line2 = addr['address_line2'] ?? '';
      final city = addr['city'] ?? '';
      setState(() {
        _locationArea = line2.isNotEmpty ? line2 : city.isNotEmpty ? city : 'Set Location';
        _locationDetail = line1;
      });
      final lat = double.tryParse(addr['latitude'] ?? '');
      final lng = double.tryParse(addr['longitude'] ?? '');
      if (lat != null && lng != null) {
        try {
          final result = await DeliveryZoneService().checkLocation(lat, lng);
          if (!mounted) return;
          setState(() { _serviceable = result.serviceable; _zoneChecked = true; });
        } catch (_) {
          if (!mounted) return;
          setState(() { _serviceable = true; _zoneChecked = true; });
        }
      }
    } else {
      _detectCurrentLocation();
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() { _locationArea = 'Detecting...'; _locationDetail = ''; });
    final loc = await LocationService().getCurrentLocation();
    if (!mounted) return;
    if (loc.error != null) {
      setState(() { _locationArea = 'Set Location'; _locationDetail = 'Tap to set your area'; _zoneChecked = true; });
      return;
    }
    try {
      final data = await _api.reverseGeocode(loc.latitude, loc.longitude);
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gps_address_line', data['address_line1'] ?? '');
      await prefs.setString('gps_address_line2', data['address_line2'] ?? '');
      await prefs.setString('gps_city', data['city'] ?? '');
      await prefs.setString('gps_latitude', '${loc.latitude}');
      await prefs.setString('gps_longitude', '${loc.longitude}');
      final area = data['address_line2'] ?? '';
      final city = data['city'] ?? '';
      final line1 = data['address_line1'] ?? '';
      if (mounted) setState(() {
        _locationArea = area.isNotEmpty ? area : city.isNotEmpty ? city : 'Set Location';
        _locationDetail = line1;
      });
    } catch (_) {
      if (mounted) setState(() { _locationArea = 'Set Location'; _locationDetail = 'Tap to set your area'; });
    }
    try {
      final zoneResult = await DeliveryZoneService().checkLocation(loc.latitude, loc.longitude);
      if (!mounted) return;
      setState(() { _serviceable = zoneResult.serviceable; _zoneChecked = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _serviceable = true; _zoneChecked = true; });
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
    const maxRetries = 8;
    setState(() { _loadingProducts = true; _error = false; });
    _api.warmUp();
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final cats = await _api.getCategories();
        final prods = await _api.getProducts();
        if (!mounted) return;
        setState(() {
          _categories = ['All', ...cats.map<String>((c) => c['name'] as String)];
          _allProducts = prods.cast<Map<String, dynamic>>();
          _loadingProducts = false;
        });
        return;
      } catch (e) {
        debugPrint('HomePage._loadData attempt $attempt/$maxRetries error: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: (attempt * 3).clamp(3, 15)));
          if (!mounted) return;
        }
      }
    }
    if (!mounted) return;
    setState(() { _loadingProducts = false; _error = true; });
  }

  Future<void> _retryLoad() async {
    await _loadGpsAddress();
    await _loadData();
  }

  Future<void> _loadProfile() async {
    try {
      final userData = await _api.getSavedUser();
      if (!mounted) return;
      setState(() => _user = userData);
    } catch (_) {}
  }

  Future<bool> _requireLogin() async {
    final token = await _api.getToken();
    if (token != null) return true;
    final loggedIn = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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
      final confirmed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const MapPickerPage()));
      if (confirmed == true) _loadGpsAddress();
    } else {
      _loadGpsAddress();
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final name = (_user?['name'] as String? ?? 'User').trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final pages = [
      _buildHome(initial, name),
      _buildCategoriesTab(),
      const OffersPage(),
      CartPage(onBrowse: () => setState(() => _selectedIndex = 0)),
      _buildAccount(initial, name),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_filled, Icons.home_outlined, 'Home'),
      (Icons.category, Icons.category_outlined, 'Categories'),
      (Icons.local_offer, Icons.local_offer_outlined, 'Offers'),
      (Icons.shopping_cart, Icons.shopping_cart_outlined, 'Cart'),
      (Icons.person, Icons.person_outlined, 'Account'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(items.length, (i) {
                final isSelected = _selectedIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (i >= 3) {
                        final token = await _api.getToken();
                        if (token == null) {
                          final loggedIn = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                          if (loggedIn != true) return;
                          await _loadProfile();
                        }
                      }
                      setState(() => _selectedIndex = i);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 30,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                isSelected ? items[i].$1 : items[i].$2,
                                size: 26,
                                color: isSelected ? _orange : const Color(0xFF9E9E9E),
                              ),
                              if (i == 3)
                                ListenableBuilder(
                                  listenable: cartNotifier,
                                  builder: (_, _) => cartNotifier.itemCount > 0
                                      ? Positioned(
                                          right: -9, top: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: AppColors.error, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                            child: Text('${cartNotifier.itemCount}',
                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: isSelected ? 20 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: isSelected ? _orange : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].$3, style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? _orange : const Color(0xFF9E9E9E),
                        )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOME TAB
  // ---------------------------------------------------------------------------

  int _selectedChip = -1;

  Widget _buildHome(String initial, String name) {
    return Container(
      color: _bgWarm,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildCompactHeader(initial, name),
            _buildSmartChips(),
            const SizedBox(height: 8),
            _buildCategoryPills(),
            const SizedBox(height: 10),
            _buildOfferBanners(),
            const SizedBox(height: 14),
            _buildProductSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(String initial) {
    final imageUrl = _user?['profile_image'] as String? ?? '';
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 4),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: imageUrl.isNotEmpty
            ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(imageUrl))
            : CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white.withAlpha(40),
                child: Text(initial,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }

  Widget _buildCompactHeader(String initial, String name) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_orange, _orangeSecondary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildHeaderAvatar(initial),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showLocationPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(_locationArea,
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.white.withAlpha(35), borderRadius: BorderRadius.circular(5)),
                                      child: const Text('HOME', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                    ),
                                  ],
                                ),
                                if (_locationDetail.isNotEmpty)
                                  Text(_locationDetail,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 9, color: Colors.white.withAlpha(180))),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ListenableBuilder(
                  listenable: wishlistNotifier,
                  builder: (_, _) => IconButton(
                    icon: Icon(
                      wishlistNotifier.itemCount > 0 ? Icons.favorite : Icons.favorite_border,
                      color: Colors.white, size: 22,
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage())),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                ListenableBuilder(
                  listenable: notificationService,
                  builder: (_, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      if (notificationService.unreadCount > 0)
                        Positioned(
                          right: 4, top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            child: Text(
                              '${notificationService.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
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
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22),
                        onPressed: () => setState(() => _selectedIndex = 3),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      if (cartNotifier.itemCount > 0)
                        Positioned(
                          right: 4, top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                            child: Text('${cartNotifier.itemCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4)),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search products',
                            hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 15, fontWeight: FontWeight.w400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(Icons.search, color: Color(0xFF999999), size: 22),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () { _searchController.clear(); setState(() {}); },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  )
                                : null,
                          ),
                          style: const TextStyle(fontSize: 15, color: Color(0xFF222222)),
                          cursorColor: _orange,
                        ),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 56,
                      decoration: const BoxDecoration(color: _orange),
                      child: IconButton(
                        icon: const Icon(Icons.tune, color: Colors.white, size: 22),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: _smartChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = _smartChips[i];
          final isSelected = _selectedChip == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedChip = isSelected ? -1 : i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? _orange : Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE8E8E8)),
                boxShadow: isSelected
                    ? [BoxShadow(color: _orange.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(chip['emoji'] as String, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(chip['label'] as String, style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF444444),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPills() {
    final cats = _categories.where((c) => c != 'All').toList();
    if (cats.isEmpty && _loadingProducts) {
      return SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => Container(
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    if (cats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = cats[i];
          final isSelected = _selectedCategory == cat;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _orange : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE8E8E8)),
                boxShadow: isSelected
                    ? [BoxShadow(color: _orange.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_catEmoji(cat), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(cat, style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF444444),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfferBanners() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _offerBanners.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final banner = _offerBanners[i];
          return Container(
            width: MediaQuery.of(context).size.width * 0.75,
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(banner['color'] as int),
                  Color(banner['color'] as int).withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Color(banner['color'] as int).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(banner['title'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 4),
                      Text(banner['subtitle'] as String,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, height: 1.3)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Shop Now \u2192',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(banner['emoji'] as String, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductSection() {
    final products = _filteredProducts;

    return ListenableBuilder(
      listenable: Listenable.merge([cartNotifier, wishlistNotifier]),
      builder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3, height: 18,
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_selectedCategory == 'All' ? 'All Products' : _selectedCategory,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${products.length} items',
                    style: const TextStyle(fontSize: 9, color: _orange, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (_categories.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('See All', style: TextStyle(fontSize: 11, color: _orange, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 14, color: _orange),
                      ],
                    ),
                  ),
              ],
            ),
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
                    const Text('Coming Soon!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
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
                child: LoadingWidget(message: 'Loading products\u2026'),
              )
            else if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: ErrorStateWidget(message: 'Failed to load products', onRetry: _retryLoad),
              )
            else if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyStateWidget(icon: Icons.inventory_2_outlined, title: 'No products in this category', subtitle: 'Check back later for new items'),
              )
            else
              ProductGrid(
                products: products.map((p) => _toGroceryProduct(p)).toList(),
                cartMap: {for (final p in products) p.id.hashCode: cartNotifier.isInCart(p.id)},
                favMap: {for (final p in products) p.name: wishlistNotifier.contains(p.id)},
                getImages: (gp) {
                  final p = products.firstWhere((e) => e.name == gp.name);
                  return p.images;
                },
                onAdd: (gp) async {
                  final p = products.firstWhere((e) => e.name == gp.name);
                  if (!await _requireLogin()) return;
                  if (!mounted) return;
                  await cartNotifier.add(p.id, name: p.name, qty: p.qty, price: p.price);
                  if (!mounted) return;
                  AppSnackbar.show(context, '${p.name} added to cart');
                },
                onFav: (gp) {
                  final p = products.firstWhere((e) => e.name == gp.name);
                  wishlistNotifier.toggle(p.id);
                },
                onTap: (gp) {
                  final p = products.firstWhere((e) => e.name == gp.name);
                  final count = cartNotifier.itemCountFor(p.id);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      icon: p.icon, color: _orange, name: p.name, price: p.price, qty: p.qty, images: p.images,
                      inCart: count > 0,
                      onAdd: () async {
                        if (!await _requireLogin()) return;
                        if (!mounted) return;
                        await cartNotifier.add(p.id, name: p.name, qty: p.qty, price: p.price);
                      },
                    ),
                  ));
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES TAB
  // ---------------------------------------------------------------------------

  Widget _buildCategoriesTab() {
    final cats = _categories.where((c) => c != 'All').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text('Shop by Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
          const SizedBox(height: 20),
          if (_loadingProducts)
            const Padding(padding: EdgeInsets.only(top: 40), child: LoadingWidget(message: 'Loading categories\u2026'))
          else if (_error)
            ErrorStateWidget(onRetry: _retryLoad)
          else if (cats.isEmpty)
            const EmptyStateWidget(icon: Icons.category_outlined, title: 'No categories available', subtitle: 'Check back later')
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 32, color: _orange),
                        ),
                        const SizedBox(height: 12),
                        Text(cat, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF222222)), textAlign: TextAlign.center),
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

  // ---------------------------------------------------------------------------
  // ACCOUNT TAB
  // ---------------------------------------------------------------------------

  Widget _buildAccount(String initial, String name) {
    final email = _user?['email'] ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: (constraints.maxHeight * 0.06).clamp(30, 50)),
              _buildAvatar(initial),
              const SizedBox(height: 14),
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(fontSize: 14, color: Color(0xFF757575))),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => EditProfilePage(user: _user ?? {})));
                  if (result != null) _loadProfile();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: _orange),
                      SizedBox(width: 4),
                      Text('Edit Profile', style: TextStyle(fontSize: 12, color: _orange, fontWeight: FontWeight.w600)),
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
                _menuItem(Icons.notifications_outlined, 'Notifications', 'Manage alerts & updates', () => AppSnackbar.show(context, 'Coming soon!', type: SnackbarType.info)),
                _menuItem(Icons.favorite, 'Favorites', '${wishlistNotifier.itemCount} items', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistPage()))),
                _menuItem(Icons.support_outlined, 'Help & Support', 'FAQs & contact', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportPage()))),
              ]),
              const SizedBox(height: 16),
              _menuCard([
                _menuItem(Icons.settings_outlined, 'Settings', 'App preferences', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
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

  Widget _buildAvatar(String initial) {
    final imageUrl = _user?['profile_image'] as String? ?? '';
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(imageUrl),
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: _orange.withValues(alpha: 0.1),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: _orange,
        child: Text(initial,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ),
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
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: _orange),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFFBDBDBD))),
            ])),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper classes & functions
// ---------------------------------------------------------------------------

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

String _emojiFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('rice')) return '\u{1F35A}';
  if (n.contains('milk') || n.contains('curd') || n.contains('paneer') || n.contains('cheese') || n.contains('butter') || n.contains('ghee'))
    return '\u{1F95B}';
  if (n.contains('coffee') || n.contains('boost') || n.contains('horlicks') || n.contains('tea')) return '\u2615';
  if (n.contains('biscuit') || n.contains('cookie')) return '\u{1F36A}';
  if (n.contains('chip') || n.contains('popcorn') || n.contains('noodle')) return '\u{1F37F}';
  if (n.contains('banana') || n.contains('apple') || n.contains('fruit')) return '\u{1F34C}';
  if (n.contains('notebook') || n.contains('pen') || n.contains('pencil')) return '\u{1F4DD}';
  return '\u{1F6D2}';
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
  final mrp = (p.price * 1.18).round();
  return GroceryProduct(
    id: p.id.hashCode,
    name: p.name,
    weight: p.qty,
    price: p.price.toDouble(),
    originalPrice: mrp.toDouble(),
    discountPercent: ((mrp - p.price) / mrp * 100).round(),
    emoji: _emojiFor(p.name),
    imageBg: _colorFor(p.category),
  );
}
