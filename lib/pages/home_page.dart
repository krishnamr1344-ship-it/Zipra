import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
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

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _api = ApiService();
  int _selectedIndex = 0;
  String _locationArea = '';
  String _locationDetail = '';
  String _selectedCategory = 'All';
  Map<String, dynamic>? _user;
  bool _firstResume = true;
  bool _detecting = false;

  List<String> _categories = ['All'];
  List<Map<String, dynamic>> _categoriesData = [];
  List<Map<String, dynamic>> _allProducts = [];
  bool _loadingProducts = true;
  bool _error = false;
  bool _serviceable = true;
  bool _zoneChecked = false;

  final _searchController = TextEditingController();
  final _heroCarouselController = PageController();
  int _currentHeroPage = 0;
  Timer? _carouselTimer;
  final _catCarouselController = PageController();
  int _currentCatCarouselPage = 0;
  bool _canPop = false;

  static const _orange = Color(0xFFFF6B00);
  static const _orangeSecondary = Color(0xFFFF8F00);
  static const _bgWarm = Color(0xFFFFF8F3);

  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _loadData();
    _checkAndDetectLocation();
    cartNotifier.load();
    wishlistNotifier.load();
    notificationService.load();
    _startCarouselTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_firstResume) {
        _firstResume = false;
        return;
      }
      _checkAndDetectLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _heroCarouselController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      try {
        if (_heroCarouselController.hasClients) {
          final len = _banners.length;
          if (len == 0) return;
          final next = (_currentHeroPage + 1) % len;
          _heroCarouselController.animateToPage(
            next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _checkAndDetectLocation() async {
    if (_detecting) return;
    _detecting = true;
    try {
      setState(() {
        _locationArea = 'Checking GPS...';
        _locationDetail = '';
      });
      final loc = await LocationService().getCurrentLocation();
      if (!mounted) return;

      if (loc.error != null) {
        debugPrint('GPS check failed: ${loc.error}');
        String msg;
        if (loc.error!.contains('disabled')) {
          msg = 'Please enable GPS';
        } else if (loc.error!.contains('deniedForever')) {
          msg = 'Location blocked';
        } else {
          msg = 'Set Location';
        }
        if (mounted)
          setState(() {
            _locationArea = msg;
            _locationDetail = '';
            _zoneChecked = true;
          });
        return;
      }

      debugPrint('GPS coords: ${loc.latitude}, ${loc.longitude}');
      final data = await _api.reverseGeocode(loc.latitude, loc.longitude);
      debugPrint(
        'Reverse geocode result: ${data['address_line2']}, ${data['address_line1']}',
      );

      if (loc.latitude == 0 && loc.longitude == 0 && mounted) {
        setState(() {
          _locationArea = 'Set Location';
          _locationDetail = '';
        });
        return;
      }

      final area = data['address_line2'] ?? '';
      final line1 = data['address_line1'] ?? '';
      debugPrint('Final displayed area: $area');

      if (mounted) {
        setState(() {
          _locationArea = area.isNotEmpty ? area : 'Set Location';
          _locationDetail = line1;
        });
      }

      try {
        final zoneResult = await DeliveryZoneService().checkLocation(
          loc.latitude,
          loc.longitude,
        );
        if (!mounted) return;
        setState(() {
          _serviceable = zoneResult.serviceable;
          _zoneChecked = true;
        });
      } catch (e) {
        debugPrint("pages.home_page zone: $e");
        if (!mounted) return;
        setState(() {
          _serviceable = true;
          _zoneChecked = true;
        });
      }
    } finally {
      _detecting = false;
    }
  }

  Future<void> _readSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final line2 = prefs.getString('gps_address_line2') ?? '';
    final line1 = prefs.getString('gps_address_line') ?? '';
    if (mounted) {
      setState(() {
        _locationArea = line2.isNotEmpty ? line2 : 'Set Location';
        _locationDetail = line1;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final enabled = _allProducts.where((p) => p['is_enabled'] != false);
    if (_selectedCategory == 'All') return enabled.toList();
    return enabled
        .where((p) => p['category_name'] == _selectedCategory)
        .toList();
  }

  List<GroceryProduct> _toGroceryProducts(List<Map<String, dynamic>> items) {
    return items.map((p) {
      return GroceryProduct.fromMap({
        ...p,
        'name': p['name'] ?? '',
        'price': ((p['price'] ?? 0) as num).toDouble(),
        'mrp': ((p['mrp'] ?? p['original_price'] ?? p['price'] ?? 0) as num)
            .toDouble(),
        'unit': p['unit'] ?? '',
        'images': p['images'] is List
            ? (p['images'] as List).cast<String>()
            : <String>[],
        'stock': p['stock'] ?? 0,
        'is_enabled': p['is_enabled'] != false,
        'category_name': p['category_name'] ?? '',
      });
    }).toList();
  }

  Future<void> _loadData() async {
    const maxRetries = 8;
    setState(() {
      _loadingProducts = true;
      _error = false;
    });
    _api.warmUp();
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final cats = await _api.getCategories();
        final prods = await _api.getProducts();
        if (!mounted) return;
        setState(() {
          _categoriesData = cats.cast<Map<String, dynamic>>();
          _categories = [
            'All',
            ...cats.map<String>((c) => c['name'] as String),
          ];
          _allProducts = prods.cast<Map<String, dynamic>>();
          _loadingProducts = false;
        });
        _loadBanners();
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
    setState(() {
      _loadingProducts = false;
      _error = true;
    });
  }

  Future<void> _retryLoad() async {
    _checkAndDetectLocation();
    await _loadData();
  }

  Future<void> _loadProfile() async {
    try {
      final userData = await _api.getSavedUser();
      if (!mounted) return;
      setState(() => _user = userData);
      await _api.getCategories();
    } catch (e) {
      if (_isAuthError(e)) {
        await _handleExpiredToken();
        return;
      }
      debugPrint("pages.home_page: $e");
    }
  }

  bool _isAuthError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('401') || msg.contains('unauthorized') || msg.contains('token expired') || msg.contains('not authenticated');
  }

  Future<void> _handleExpiredToken() async {
    await _api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _loadBanners() async {
    try {
      final data = await _api.getBanners();
      if (!mounted) return;
      setState(() {
        _banners = data.map<Map<String, dynamic>>((b) {
          final banner = b as Map<String, dynamic>;
          final hexColor = (banner['color'] as String?) ?? 'FF6B00';
          return {
            'title': banner['title'] as String? ?? '',
            'subtitle': banner['subtitle'] as String? ?? '',
            'color': int.parse('FF$hexColor', radix: 16),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('pages.home_page:_loadBanners $e');
    }
  }

  Future<bool> _requireLogin() async {
    final token = await _api.getToken();
    if (token != null) return true;
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    return loggedIn == true;
  }

  void _onTabSelected(int index) async {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
      return;
    }
    if (!await _requireLogin()) return;
    if (index == 4) _loadProfile();
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await _api.logout();
    final prefs = await SharedPreferences.getInstance();
    final gpsKeys = [
      'gps_address_id',
      'gps_address_line',
      'gps_address_line2',
      'gps_city',
      'gps_landmark',
      'gps_latitude',
      'gps_longitude',
      'gps_pincode',
      'gps_address_type',
      'gps_house_number',
      'gps_floor_number',
    ];
    for (final key in gpsKeys) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _showLocationPicker() async {
    await _checkAndDetectLocation();
    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LocationPickerSheet(),
    );
    if (!mounted) return;
    if (action == 'map') {
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const MapPickerPage()),
      );
      if (confirmed == true) _readSavedLocation();
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

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit', style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
        if (exit == true && context.mounted) {
          setState(() => _canPop = true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: _buildBottomNav(),
      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final isSelected = _selectedIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabSelected(i),
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
                              color: isSelected
                                  ? _orange
                                  : const Color(0xFF9E9E9E),
                            ),
                            if (i == 3)
                              ListenableBuilder(
                                listenable: cartNotifier,
                                builder: (_, _) => cartNotifier.itemCount > 0
                                    ? Positioned(
                                        right: -9,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
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
                      Text(
                        items[i].$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? _orange : const Color(0xFF9E9E9E),
                        ),
                      ),
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

  Widget _buildHome(String initial, String name) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _retryLoad,
            color: _orange,
            child: Container(
              color: _bgWarm,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildCompactHeader(initial, name),
                    _buildHeroBanner(),
                    _buildProductSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildFloatingCartBar(),
      ],
    );
  }

  Widget _buildHeaderAvatar(String initial) {
    final imageUrl = _user?['profile_image'] as String? ?? '';
    return GestureDetector(
      onTap: () async {
        if (!await _requireLogin()) return;
        setState(() => _selectedIndex = 4);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: imageUrl.isNotEmpty
            ? CircleAvatar(radius: 15, backgroundImage: NetworkImage(imageUrl))
            : CircleAvatar(
                radius: 15,
                backgroundColor: Colors.white.withAlpha(40),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCompactHeader(String initial, String name) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_orange, _orangeSecondary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
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
                                            fontWeight: FontWeight.w600,
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
                                          color: Colors.white.withAlpha(35),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: const Text(
                                          'HOME',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7,
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
                                        fontSize: 9,
                                        color: Colors.white.withAlpha(180),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.white70,
                            ),
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
                        wishlistNotifier.itemCount > 0
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WishlistPage()),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: notificationService,
                    builder: (_, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        if (notificationService.unreadCount > 0)
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
                                '${notificationService.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
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
                            size: 22,
                          ),
                          onPressed: () async {
                            if (!await _requireLogin()) return;
                            if (!mounted) return;
                            setState(() => _selectedIndex = 3);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        if (cartNotifier.itemCount > 0)
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
                                '${cartNotifier.itemCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
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
                              hintStyle: const TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 17,
                              ),
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 2),
                                child: Icon(
                                  Icons.search,
                                  color: Color(0xFF999999),
                                  size: 22,
                                ),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    )
                                  : null,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF222222),
                            ),
                            cursorColor: _orange,
                          ),
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 56,
                        decoration: const BoxDecoration(color: _orange),
                        child: IconButton(
                          icon: const Icon(
                            Icons.tune,
                            color: Colors.white,
                            size: 22,
                          ),
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
      ),
    );
  }

  Widget _buildProductSection() {
    final rawProducts = _filteredProducts;
    final products = _toGroceryProducts(rawProducts);

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
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedCategory == 'All'
                      ? 'All Products'
                      : _selectedCategory,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${products.length} items',
                    style: const TextStyle(
                      fontSize: 9,
                      color: _orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (_categories.length > 1)
                  GestureDetector(
                    onTap: () => setState(() => _selectedIndex = 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 11,
                            color: _orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                    const Text(
                      'Coming Soon!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF222222),
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
              _buildSkeletonGrid()
            else if (_error)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: ErrorStateWidget(
                  message: 'Failed to load products',
                  onRetry: _retryLoad,
                ),
              )
            else if (products.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: EmptyStateWidget(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products in this category',
                  subtitle: 'Check back later for new items',
                ),
              )
            else
              ProductGrid(
                products: products,
                favMap: {
                  for (final p in products)
                    p.id: wishlistNotifier.contains(p.id),
                },
                getImages: (gp) => gp.images,
                onAdd: (gp) async {
                  if (!await _requireLogin()) return;
                  if (!mounted) return;
                  await cartNotifier.add(
                    gp.id,
                    name: gp.name,
                    qty: gp.unit,
                    price: gp.sellingPrice.round(),
                  );
                  if (!mounted) return;
                  AppSnackbar.show(context, '${gp.name} added to cart');
                },
                onDecrement: (gp) async {
                  if (!await _requireLogin()) return;
                  if (!mounted) return;
                  await cartNotifier.updateCount(gp.id, -1);
                },
                onFav: (gp) => wishlistNotifier.toggle(gp.id),
                onTap: (gp) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(
                        icon: Icons.shopping_bag,
                        color: _orange,
                        name: gp.name,
                        productId: gp.id,
                        price: gp.sellingPrice.round(),
                        qty: gp.unit,
                        images: gp.images,
                        isEnabled: gp.isEnabled,
                        discountPercent: gp.discountPercent ?? 0,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    final screenW = MediaQuery.of(context).size.width;
    final spacing = screenW * 0.03;
    final cardW = (screenW - 32 - spacing) / 2;
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.5);
    final contentH = 80.0 * scale;
    final skeletonAspectRatio = cardW / (130.0 + contentH);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: skeletonAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: 6,
            itemBuilder: (_, _) => const SkeletonProductCard(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO BANNER
  // ---------------------------------------------------------------------------

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _heroCarouselController,
              onPageChanged: (i) => setState(() => _currentHeroPage = i),
              itemCount: _banners.length,
              itemBuilder: (_, i) {
                final b = _banners[i];
                final color = Color(b['color'] as int);
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                b['title'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                b['subtitle'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              GestureDetector(
                                onTap: () => setState(() => _selectedIndex = 1),
                                child: Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Shop Now',
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Center(
                              child: Text(
                                b['emoji'] as String? ?? '\u{1F6CD}\uFE0F',
                                style: const TextStyle(fontSize: 46),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentHeroPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentHeroPage == i
                      ? _orange
                      : const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FLASH SALE
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // FLOATING CART BAR
  // ---------------------------------------------------------------------------

  Widget _buildFloatingCartBar() {
    return ListenableBuilder(
      listenable: cartNotifier,
      builder: (_, _) {
        final count = cartNotifier.itemCount;
        if (count == 0) return const SizedBox.shrink();
        final total = cartNotifier.total;
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 6,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom + 6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cart icon with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: _orange,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      child: Text(
                        '$count',
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
              const SizedBox(width: 12),
              // Text details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count Item${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ],
                ),
              ),
              // Total
              Text(
                '\u20B9$total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(width: 8),
              // View Cart button
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (!await _requireLogin()) return;
                  if (!mounted) return;
                  if (!mounted) return;
                  setState(() => _selectedIndex = 3);
                },
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _orange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'View Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORY CARD - shared by Home & Categories tabs
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _catMeta(Map<String, dynamic> catData) {
    const fallback = <String, Map<String, dynamic>>{
      'All': {
        'gradient': [0xFFE8F5E9, 0xFFC8E6C9],
        'emoji': '\u{1F4CB}',
      },
      'Fresh Dairy': {
        'gradient': [0xFFFFF3E0, 0xFFFFE0B2],
        'emoji': '\u{1F95B}',
      },
      'Rice & Grocery': {
        'gradient': [0xFFFFF8E1, 0xFFFFECB3],
        'emoji': '\u{1F35E}',
      },
      'Dals': {
        'gradient': [0xFFFFF3E0, 0xFFFFCC80],
        'emoji': '\u{1F330}',
      },
      'Oils': {
        'gradient': [0xFFFFF3E0, 0xFFFFCC80],
        'emoji': '\u{1F6ED}',
      },
      'Masala': {
        'gradient': [0xFFFBE9E7, 0xFFFFCDD2],
        'emoji': '\u{1F336}\uFE0F',
      },
      'Tea & Beverages': {
        'gradient': [0xFFFFF3E0, 0xFFFFE0B2],
        'emoji': '\u2615',
      },
      'Bathroom & Personal Care': {
        'gradient': [0xFFFCE4EC, 0xFFF8BBD0],
        'emoji': '\u{1F9F4}',
      },
    };

    final name = catData['name'] as String;
    final fb = fallback[name] ?? fallback.values.first;
    return <String, dynamic>{
      'image': catData['image'] as String?,
      'gradient': fb['gradient'],
      'emoji': fb['emoji'],
    };
  }

  Widget _buildCategoryCard(String cat, Map<String, dynamic> meta) {
    final gradients = meta['gradient'] as List<int>;
    final imageUrl = meta['image'] as String? ?? '';
    final emoji = meta['emoji'] as String? ?? '\u{1F6D2}';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategory = cat;
          _selectedIndex = 0;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(gradients[0]), Color(gradients[1])],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, chunk) => chunk == null
                            ? child
                            : Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                        errorBuilder: (_, _, _) => Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            cat,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  // Shared category grid widget used by Home & Categories tabs
  Widget _buildCategoryGrid() {
    final cats = List<String>.from(_categories);
    final catMetaMap = <String, Map<String, dynamic>>{};
    const fallback = <String, dynamic>{
      'image': null,
      'gradient': [0xFFF5F5F5, 0xFFEEEEEE],
      'emoji': '\u{1F6D2}',
    };
    for (final catData in _categoriesData) {
      final name = catData['name'] as String;
      catMetaMap[name] = _catMeta(catData);
    }
    catMetaMap['All'] = const <String, dynamic>{
      'image': null,
      'gradient': [0xFFE8F5E9, 0xFFC8E6C9],
      'emoji': '\u{1F4CB}',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Shop by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              return _buildCategoryCard(
                cat,
                catMetaMap[cat] ?? fallback,
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES TAB
  // ---------------------------------------------------------------------------

  Widget _buildCategoriesTab() {
    final cats = List<String>.from(_categories);
    final safeTop = MediaQuery.of(context).padding.top;

    const catMetaFallback = <String, Map<String, dynamic>>{
      'All': {
        'gradient': [0xFFE8F5E9, 0xFFC8E6C9],
        'emoji': '\u{1F4CB}',
      },
      'Fresh Dairy': {
        'gradient': [0xFFFFF3E0, 0xFFFFE0B2],
        'emoji': '\u{1F95B}',
      },
      'Rice & Grocery': {
        'gradient': [0xFFFFF8E1, 0xFFFFECB3],
        'emoji': '\u{1F35E}',
      },
      'Dals': {
        'gradient': [0xFFFFF3E0, 0xFFFFCC80],
        'emoji': '\u{1F330}',
      },
      'Oils': {
        'gradient': [0xFFFFF3E0, 0xFFFFCC80],
        'emoji': '\u{1F6ED}',
      },
      'Masala': {
        'gradient': [0xFFFBE9E7, 0xFFFFCDD2],
        'emoji': '\u{1F336}\uFE0F',
      },
      'Tea & Beverages': {
        'gradient': [0xFFFFF3E0, 0xFFFFE0B2],
        'emoji': '\u2615',
      },
      'Bathroom & Personal Care': {
        'gradient': [0xFFFCE4EC, 0xFFF8BBD0],
        'emoji': '\u{1F9F4}',
      },
    };

    Map<String, dynamic> catMeta(Map<String, dynamic> catData) {
      final name = catData['name'] as String;
      final fallback = catMetaFallback[name] ?? catMetaFallback.values.first;
      return <String, dynamic>{
        'image': catData['image'] as String?,
        'gradient': fallback['gradient'],
        'emoji': fallback['emoji'],
      };
    }

    final catMetaMap = <String, Map<String, dynamic>>{};
    for (final catData in _categoriesData) {
      final name = catData['name'] as String;
      catMetaMap[name] = catMeta(catData);
    }
    catMetaMap['All'] = const <String, dynamic>{
      'image': null,
      'gradient': [0xFFE8F5E9, 0xFFC8E6C9],
      'emoji': '\u{1F4CB}',
    };

    final catCounts = <String, int>{};
    for (final p in _allProducts) {
      final cn = p['category_name'] as String? ?? '';
      catCounts[cn] = (catCounts[cn] ?? 0) + 1;
    }

    final topOrdered = cats.where((c) => (catCounts[c] ?? 0) >= 3).toList();

    // ---------------------------------------------------
    // Most Ordered section builder
    // ---------------------------------------------------
    Widget buildMostOrdered() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Text('\u{1F525}', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text(
                  'Most Ordered',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF222222),
                  ),
                ),
                const Spacer(),
                Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _orange,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: _orange),
              ],
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topOrdered.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final cat = topOrdered[i];
                final meta =
                    catMetaMap[cat] ??
                    <String, dynamic>{
                      'emoji': '\u{1F6D2}',
                      'gradient': [0xFFFFF3E0, 0xFFFFE0B2],
                    };
                final gradients = meta['gradient'] as List<int>;
                final badge = null;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategory = cat;
                      _selectedIndex = 0;
                    });
                  },
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(gradients[0]),
                                Color(gradients[1]),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  meta['emoji'] as String,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              if (badge != null)
                                Positioned(
                                  top: 1,
                                  right: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badge == 'HOT'
                                          ? const Color(0xFFFF3D00)
                                          : _orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      badge == 'HOT' ? '\u{1F525}' : badge[0],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 6,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        Text(
                          '${catCounts[cat] ?? 0} items',
                          style: const TextStyle(
                            fontSize: 7,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    // ---------------------------------------------------
    // Promotional carousel builder
    // ---------------------------------------------------
    Widget buildPromoCarousel() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          children: [
            SizedBox(
              height: 110,
              child: PageView.builder(
                controller: _catCarouselController,
                onPageChanged: (i) =>
                    setState(() => _currentCatCarouselPage = i),
                itemCount: _banners.length,
                itemBuilder: (_, i) {
                  final banner = _banners[i];
                  final title = banner['title'] as String;
                  final subtitle = banner['subtitle'] as String;
                  final color = banner['color'] as int;
                  final emoji = banner['emoji'] as String? ?? '\u{1F6CD}\uFE0F';
                  return Container(
                    margin: const EdgeInsets.only(right: 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(color),
                          Color(color).withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(color).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => setState(() => _selectedIndex = 1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Shop Now \u2192',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  width: _currentCatCarouselPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentCatCarouselPage == i
                        ? _orange
                        : const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------
    // Floating cart builder
    // ---------------------------------------------------
    Widget buildFloatingCart() {
      final count = cartNotifier.itemCount;
      final total = cartNotifier.total;
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedIndex = 3);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFFF8F00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _orange.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 22,
                  ),
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _orange,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                '\u20B9${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 10,
              ),
            ],
          ),
        ),
      );
    }

    // ---------------------------------------------------
    // Main layout
    // ---------------------------------------------------
    return Stack(
      children: [
        if (_loadingProducts)
          const Center(
            child: LoadingWidget(message: 'Loading categories\u2026'),
          )
        else if (_error)
          ErrorStateWidget(onRetry: _retryLoad)
        else if (cats.isEmpty)
          const EmptyStateWidget(
            icon: Icons.category_outlined,
            title: 'No categories available',
            subtitle: 'Check back later',
          )
        else
          CustomScrollView(
            slivers: [
              // Sticky search header
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  safeTop: safeTop,
                  searchController: _searchController,
                  locationArea: _locationArea,
                  onLocationTap: _showLocationPicker,
                  cartItemCount: cartNotifier.itemCount,
                  onSearchChanged: (_) => setState(() {}),
                  onNotificationTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                  onCartTap: () async {
                    HapticFeedback.lightImpact();
                    if (!await _requireLogin()) return;
                    if (!mounted) return;
                    setState(() => _selectedIndex = 3);
                  },
                ),
              ),

              // Most Ordered section
              if (topOrdered.isNotEmpty)
                SliverToBoxAdapter(child: buildMostOrdered()),

              // Promotional carousel
              SliverToBoxAdapter(child: buildPromoCarousel()),

              // Category grid header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Shop by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Category grid (4 per row)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: cats.length,
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      return _buildCategoryCard(
                        cat,
                        catMetaMap[cat] ??
                            <String, dynamic>{
                              'image': null,
                              'gradient': [0xFFF5F5F5, 0xFFEEEEEE],
                              'emoji': '\u{1F6D2}',
                            },
                      );
                    },
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),

        // Floating cart button
        if (!_loadingProducts && !_error && cats.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: ListenableBuilder(
              listenable: cartNotifier,
              builder: (_, _) {
                if (cartNotifier.itemCount == 0) return const SizedBox.shrink();
                return buildFloatingCart();
              },
            ),
          ),
      ],
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
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
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
                  if (result != null) _loadProfile();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 14, color: _orange),
                      SizedBox(width: 4),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: _orange,
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
                      color: Color(0xFFBDBDBD),
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
                  () => AppSnackbar.show(
                    context,
                    'Coming soon!',
                    type: SnackbarType.info,
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

  Widget _buildAvatar(String initial) {
    final imageUrl = _user?['profile_image'] as String? ?? '';
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(radius: 42, backgroundImage: NetworkImage(imageUrl));
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: _orange.withValues(alpha: 0.1),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: _orange,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: _orange),
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
                      color: Color(0xFF222222),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFBDBDBD),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky search header delegate for categories tab
// ---------------------------------------------------------------------------
class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeTop;
  final TextEditingController searchController;
  final String locationArea;
  final VoidCallback onLocationTap;
  final int cartItemCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onNotificationTap;
  final VoidCallback onCartTap;

  _SearchHeaderDelegate({
    required this.safeTop,
    required this.searchController,
    required this.locationArea,
    required this.onLocationTap,
    required this.cartItemCount,
    required this.onSearchChanged,
    required this.onNotificationTap,
    required this.onCartTap,
  });

  @override
  double get maxExtent => safeTop + 8 + 36 + 8 + 44 + 8;
  // safeTop + 8 top padding + 36 location row + 8 spacing + 44 search bar + 8 bottom padding

  @override
  double get minExtent => safeTop + 8 + 44 + 8;
  // safeTop + 8 top padding + 44 search bar + 8 bottom padding

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showingLocation = maxExtent - shrinkOffset > minExtent + 10;

    return Container(
      padding: EdgeInsets.only(
        top: safeTop + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFFA726)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Location row - fades when scrolling
          AnimatedOpacity(
            opacity: showingLocation ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: showingLocation ? 36 : 0,
              child: showingLocation
                  ? Row(
                      children: [
                        GestureDetector(
                          onTap: onLocationTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    locationArea.isNotEmpty
                                        ? locationArea
                                        : 'Set Location',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onNotificationTap,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onCartTap,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                if (cartItemCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF6B00),
                                        shape: BoxShape.circle,
                                        border: Border.fromBorderSide(
                                          BorderSide(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '$cartItemCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          if (showingLocation) const SizedBox(height: 8),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, size: 20, color: Color(0xFF999999)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search in categories',
                      hintStyle: TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF222222),
                    ),
                    cursorColor: Color(0xFFFF6B00),
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.clear,
                      size: 18,
                      color: Color(0xFF999999),
                    ),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                Container(
                  width: 40,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B00),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.tune, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.locationArea != locationArea ||
        oldDelegate.cartItemCount != cartItemCount ||
        oldDelegate.searchController.text != searchController.text ||
        oldDelegate.safeTop != safeTop;
  }
}
