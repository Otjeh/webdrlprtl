import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webdlrprtl01/models/product_journey.dart';
import 'package:webdlrprtl01/models/user_profile.dart';
import 'package:webdlrprtl01/services/auth_service.dart';
import 'package:webdlrprtl01/services/deep_link_service.dart';
import 'package:webdlrprtl01/services/local_store.dart';
import 'package:webdlrprtl01/services/notification_service.dart';
import 'package:webdlrprtl01/services/supabase_service.dart';

String buildPairingQrPayload(String pairingId) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'intent://pair/$pairingId#Intent;scheme=idigi;package=eu.fivea.idigi;end';
  }

  return 'idigi://pair/$pairingId';
}

String buildPairingQrMessage(String pairingCode) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'Scan to open iDiGi on Android or enter code $pairingCode';
  }

  return 'Scan with iDiGi app or enter code $pairingCode';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseService.isDemoMode) {
    await SupabaseService.initialize();
  }

  runApp(const IdigiConfigApp());
}

class IdigiConfigApp extends StatelessWidget {
  const IdigiConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modena Dealer Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Mimo',
        scaffoldBackgroundColor: const Color(0xFFF6F3EE),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC8102E),
          brightness: Brightness.light,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _deepLinkService = DeepLinkService();
  String? _error;
  String? _status;
  bool _isLoading = false;
  Map<String, String>? _pairing;
  Timer? _pairingTimer;
  bool _pairingHandled = false;
  StreamSubscription<DeepLink>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
    _startMobilePairing();
  }

  Future<void> _initializeDeepLinks() async {
    await _deepLinkService.initialize();
    if (!mounted) return;
    _deepLinkSubscription = _deepLinkService.deepLinks.listen(_handleDeepLink);
  }

  void _handleDeepLink(DeepLink deepLink) {
    if (!mounted || _pairingHandled) return;
    if (deepLink.target == DeepLinkTarget.pairingRequest &&
        deepLink.payload != null) {
      _processPairingRequest(deepLink.payload!);
    }
  }

  void _processPairingRequest(String pairingId) async {
    _checkMobilePairing(pairingId);
  }

  Future<void> _startMobilePairing() async {
    try {
      final pairing = await SupabaseService.instance.createWebMobilePairing();
      if (!mounted) return;
      setState(() => _pairing = pairing);
      _pairingTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _checkMobilePairing(pairing['id']!),
      );
    } catch (_) {
      // Email and password login remain available if pairing is unavailable.
    }
  }

  Future<void> _checkMobilePairing(String pairingId) async {
    if (_pairingHandled) return;
    final pairing = await SupabaseService.instance.fetchWebMobilePairing(
      pairingId,
    );
    if (!mounted || pairing?['status'] != 'approved') return;
    final email = pairing?['approved_email']?.toString();
    if (email == null) return;
    final profile = await SupabaseService.instance.fetchProfileByEmail(email);
    if (!mounted || profile == null) return;
    _pairingHandled = true;
    _pairingTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            DealerDashboardPage(user: UserProfile.fromJson(profile)),
      ),
    );
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _status = 'Starting sign-in...';
      _isLoading = true;
    });

    final user = await _authService.signIn(
      email: _emailController.text,
      password: _passwordController.text,
      onStatus: (status) {
        if (mounted) setState(() => _status = status);
      },
    );

    if (user == null) {
      setState(() {
        _error = 'Invalid Gmail address or password.';
        _status = null;
        _isLoading = false;
      });
      return;
    }

    final store = LocalStore.instance;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DealerDashboardPage(user: user)),
    );
    await store.writeJson({'loggedInUser': user.toJson()});
  }

  @override
  void dispose() {
    _pairingTimer?.cancel();
    _deepLinkSubscription?.cancel();
    _deepLinkService.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: ModenaMark(),
        ),
        title: const Text('Modena Dealer Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Administrator',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AdminLoginPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_pairing != null)
                      Column(
                        children: [
                          QrImageView(
                            data: buildPairingQrPayload(_pairing!['id']!),
                            size: 148,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            buildPairingQrMessage(_pairing!['code']!),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      const SizedBox(
                        width: 148,
                        height: 148,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 28),
                    const Text(
                      'Modena Dealer Portal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF202020),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to manage your dealer operations',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Gmail address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty || !email.contains('@')) {
                          return 'Enter a valid Gmail address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) return 'Enter your password';
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ],
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        minHeight: 3,
                        value: _isLoading ? null : 1,
                      ),
                      const SizedBox(height: 8),
                      Text(_status!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_isLoading ? 'Signing in...' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Authorized dealer and distribution staff access only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductCatalogPage extends StatefulWidget {
  const ProductCatalogPage({super.key, required this.user});

  final UserProfile user;

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  static const categories = [
    'Cooking',
    'Cooling',
    'Cleaning',
    'Laundry',
    'Water Solutions',
    'Small Appliances',
    'Built-in',
    'Spare Parts',
  ];

  late final Map<String, List<Map<String, dynamic>>> products = {
    for (final category in categories)
      category: [
        {
          'id': '${category.substring(0, 2).toUpperCase()}-001',
          'name': '$category Essential',
          'stock': category == 'Spare Parts' ? 0 : 12,
        },
        {
          'id': '${category.substring(0, 2).toUpperCase()}-002',
          'name': '$category Pro',
          'stock': category == 'Cooking' ? 4 : 0,
        },
      ],
  };
  String? _selectedCategory;
  bool _saving = false;

  bool get _canAllocate => widget.user.role == 'Dealer Distribution Admin';

  Future<void> _createJourney(Map<String, dynamic> product) async {
    if (!_canAllocate || (product['stock'] as int) <= 0) return;
    setState(() => _saving = true);
    await SupabaseService.instance.createProductJourney(
      productId: product['id'] as String,
      productName: product['name'] as String,
      category: _selectedCategory!,
      initiator: widget.user.role,
      actor: 'Dealer Distribution Manager',
      action: 'allocate',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DealerDashboardPage(user: widget.user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProducts = _selectedCategory == null
        ? const <Map<String, dynamic>>[]
        : products[_selectedCategory] ?? const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose a product category',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('Role: ${widget.user.role}'),
          const SizedBox(height: 16),
          ...categories.map(
            (category) => Card(
              color: _selectedCategory == category
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                key: ValueKey('category-$category'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(category),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _selectedCategory = category),
              ),
            ),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 20),
            Text(
              'Products in $_selectedCategory',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            ...selectedProducts.map(
              (product) => Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(product['name'] as String),
                  subtitle: Text(
                    '${product['id']} · Stock: ${product['stock']}',
                  ),
                  trailing: FilledButton(
                    onPressed: _saving || !_canAllocate || product['stock'] <= 0
                        ? null
                        : () => _createJourney(product),
                    child: Text(
                      product['stock'] <= 0
                          ? 'Out of stock'
                          : _canAllocate
                          ? 'Allocate'
                          : 'Admin only',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _modules = [
    ('LoA1', 'Basic identity verification'),
    ('LoA2', 'Authenticated approval'),
    ('LoA3', 'Qualified digital signature'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'iDiGi modules',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          for (final module in _modules)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(module.$1),
                subtitle: Text(module.$2),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }
}

class ModenaLogo extends StatelessWidget {
  const ModenaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/enamod.png',
          width: 148,
          height: 148,
          semanticLabel: 'Modena logo',
        ),
      ],
    );
  }
}

class ModenaMark extends StatelessWidget {
  const ModenaMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/enamod.png',
      width: 32,
      height: 32,
      semanticLabel: 'Modena logo',
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;
  bool _isLoading = false;

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    final isValid = await SupabaseService.instance.signInAsAdministrator(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!isValid) {
      setState(() {
        _error = 'Administrator credentials are invalid or unauthorized.';
        _isLoading = false;
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AdminStaffPage()),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrator Access')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ModenaMark(),
                  const SizedBox(height: 20),
                  const Text(
                    'Staff directory administration',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Administrator email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter the administrator email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Administrator password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Enter the administrator password'
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB3261E)),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: Text(
                      _isLoading ? 'Authenticating...' : 'Open admin page',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminStaffPage extends StatefulWidget {
  const AdminStaffPage({super.key});

  @override
  State<AdminStaffPage> createState() => _AdminStaffPageState();
}

class _AdminStaffPageState extends State<AdminStaffPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _codeController = TextEditingController();
  final _loaController = TextEditingController(text: 'LoA1');
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _role = 'Dealer Distribution Admin';
  bool _saving = false;
  bool _checkingAssignment = false;
  String? _message;
  String? _assignedRole;
  String? _selectedEmail;
  bool _showEditor = false;
  bool _savingPassword = false;
  late Future<List<Map<String, dynamic>>> _profilesFuture;
  List<String> _roles = const [
    'Dealer Distribution Admin',
    'Dealer Distribution Manager',
    'Modena Warehouse Distribution Admin',
    'Modena Warehouse Distribution Manager',
    'Warehouse Manager',
    'Third Party Logistics Driver',
    'Logistics Manager',
  ];

  @override
  void initState() {
    super.initState();
    _profilesFuture = SupabaseService.instance.fetchProfiles();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final definitions = await SupabaseService.instance.fetchPortalRoles();
    if (!mounted || definitions.isEmpty) return;
    final roles = definitions
        .map((definition) => definition['role']?.toString())
        .whereType<String>()
        .toList();
    if (roles.isEmpty) return;
    setState(() {
      _roles = roles;
      if (!_roles.contains(_role)) _role = _roles.first;
    });
  }

  void _selectProfile(Map<String, dynamic> profile) {
    final role = profile['role']?.toString() ?? _roles.first;
    setState(() {
      _showEditor = true;
      _selectedEmail = profile['email']?.toString();
      _emailController.text = profile['email']?.toString() ?? '';
      _nameController.text = profile['name']?.toString() ?? '';
      _nikController.text = profile['nik']?.toString() ?? '';
      _codeController.text = profile['code']?.toString() ?? '';
      _loaController.text = profile['loa']?.toString() ?? 'LoA1';
      _role = _roles.contains(role) ? role : _roles.first;
      _assignedRole = role;
      _message = null;
    });
  }

  void _startNewUser() {
    setState(() {
      _showEditor = true;
      _selectedEmail = null;
      _emailController.clear();
      _nameController.clear();
      _nikController.clear();
      _codeController.clear();
      _loaController.text = 'LoA1';
      _role = _roles.first;
      _assignedRole = null;
      _message = null;
    });
  }

  Future<void> _savePassword() async {
    final password = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    if (password.length < 6 || password != confirmation) {
      setState(() {
        _message = password.length < 6
            ? 'Password must contain at least 6 characters.'
            : 'Passwords do not match.';
      });
      return;
    }

    final email = _selectedEmail;
    if (email == null) return;

    setState(() {
      _savingPassword = true;
      _message = null;
    });

    try {
      await SupabaseService.instance.updateUserPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _savingPassword = false;
        _showEditor = false;
        _selectedEmail = null;
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _message = 'Password updated. Select a user to make another change.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingPassword = false;
        _message = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final existing = await SupabaseService.instance.fetchProfileByEmail(
        email,
      );
      await SupabaseService.instance.saveDealerProfile({
        'email': email,
        'name': _nameController.text.trim(),
        'nik': _nikController.text.trim(),
        'role': _role,
        'code': _codeController.text.trim(),
        'loa': _loaController.text.trim(),
      });
      setState(() {
        _saving = false;
        _selectedEmail = email;
        _profilesFuture = SupabaseService.instance.fetchProfiles();
        _message = SupabaseService.isDemoMode
            ? 'Saved in demo mode. This Gmail has one role: $_role.'
            : existing == null
            ? 'Gmail linked to $_role.'
            : 'Gmail role updated from ${existing['role']} to $_role.';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _message = 'Could not save the staff profile.';
      });
    }
  }

  Future<void> _checkAssignment() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!email.contains('@')) return;

    setState(() => _checkingAssignment = true);
    final existing = await SupabaseService.instance.fetchProfileByEmail(email);
    if (!mounted) return;
    setState(() {
      _checkingAssignment = false;
      _assignedRole = existing?['role']?.toString();
      if (_assignedRole != null && _roles.contains(_assignedRole)) {
        _role = _assignedRole!;
      }
      _message = _assignedRole == null
          ? 'This Gmail is not linked to a role yet.'
          : 'Currently linked to $_assignedRole. Saving replaces that single assignment.';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _codeController.dispose();
    _loaController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Directory')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Registered users',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _profilesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Text('Could not load registered users.');
                      }

                      final profiles = snapshot.data ?? const [];
                      return Column(
                        children: [
                          for (final profile in profiles)
                            Card(
                              child: ListTile(
                                selected:
                                    _selectedEmail ==
                                    profile['email']?.toString(),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                title: Text(
                                  profile['name']?.toString() ?? 'Unnamed user',
                                ),
                                subtitle: Text(
                                  '${profile['email']}\n${profile['role']}',
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _selectProfile(profile),
                              ),
                            ),
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_add_outlined),
                              ),
                              title: const Text('Add new user'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _startNewUser,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_showEditor) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'User details and credentials',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Passwords are managed by Supabase Auth and cannot be displayed here.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Staff Gmail address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      onEditingComplete: _checkAssignment,
                      validator: (value) => (value?.contains('@') ?? false)
                          ? null
                          : 'Enter a valid Gmail address',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Staff name',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the staff name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _role = value!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nikController,
                      decoration: const InputDecoration(labelText: 'NIK'),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the NIK'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Staff code',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the staff code'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _loaController,
                      decoration: const InputDecoration(
                        labelText: 'Level of Assurance',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Enter the LoA'
                          : null,
                    ),
                    if (_selectedEmail != null) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _savingPassword ? null : _savePassword,
                        icon: _savingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.password),
                        label: Text(
                          _savingPassword
                              ? 'Saving password...'
                              : 'Save password',
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save staff profile'),
                    ),
                    if (_checkingAssignment) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Checking existing role assignment...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                  ],
                  if (!_showEditor && _message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DealerDashboardPage extends StatefulWidget {
  const DealerDashboardPage({super.key, required this.user});

  final UserProfile user;

  @override
  State<DealerDashboardPage> createState() => _DealerDashboardPageState();
}

class _DealerDashboardPageState extends State<DealerDashboardPage> {
  late Future<List<Map<String, dynamic>>> _activeJourneyFuture;
  final Set<String> _notifyingJourneyIds = {};
  String? _notificationMessage;

  @override
  void initState() {
    super.initState();
    _activeJourneyFuture = SupabaseService.instance.fetchActiveProductJourney();
  }

  Future<void> _notifyUsers(Map<String, dynamic> journey) async {
    final journeyId = journey['id']?.toString() ?? '';
    if (journeyId.isEmpty || _notifyingJourneyIds.contains(journeyId)) return;
    setState(() {
      _notifyingJourneyIds.add(journeyId);
      _notificationMessage = null;
    });

    try {
      final count = await NotificationService.instance.notifyRegisteredUsers(
        journey: journey,
        sender: widget.user.email,
      );
      if (!mounted) return;
      setState(() {
        _notifyingJourneyIds.remove(journeyId);
        _notificationMessage = 'Notified $count registered users.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifyingJourneyIds.remove(journeyId);
        _notificationMessage = 'Could not send the notification.';
      });
    }
  }

  Future<void> _openIdigiAction(Map<String, dynamic> journey) async {
    final loa = journey['loa']?.toString() ?? 'LoA2';
    final uri = loa == 'LoA3' ? 'idigi://LoA3' : 'idigi://LoA2';
    final action = loa == 'LoA3' ? 'Digital signature' : 'Authorize';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('iDiGi action'),
        content: Text('$action required\n$uri'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activeJourneyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dealer Portal Dashboard')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final rows = snapshot.data ?? const [];
        if (rows.isEmpty) {
          return ProductCatalogPage(user: widget.user);
        }

        return Scaffold(
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Center(
                child: Text(
                  widget.user.role,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            title: const Text('Dealer Portal Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_notificationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _notificationMessage!,
                    textAlign: TextAlign.center,
                  ),
                ),
              const Text(
                'Active Product Journey',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              ...rows.map((row) {
                final journeyId = row['id']?.toString() ?? '';
                final isNotifying = _notifyingJourneyIds.contains(journeyId);
                final isAssignedToUser = _actorMatchesUser(
                  row['actor']?.toString() ?? '',
                );
                final product =
                    row['product_name']?.toString() ??
                    row['product_id']?.toString() ??
                    row['state']?.toString() ??
                    'Product';
                final status = row['status']?.toString() ?? 'pending';
                final initiator = row['initiator']?.toString() ?? 'Unknown';
                final actor = row['actor']?.toString() ?? 'Unknown';
                final loa = row['loa']?.toString() ?? 'LoA';
                final currentState =
                    row['current_state']?.toString() ?? 'Available';
                final newState =
                    row['new_state']?.toString() ??
                    row['state']?.toString() ??
                    'Unknown';
                return Card(
                  color: isAssignedToUser
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.route),
                        title: Text(
                          '$product, $status, $initiator, $actor, $loa, $currentState, $newState',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isAssignedToUser
                            ? OutlinedButton(
                                onPressed: () => _openIdigiAction(row),
                                child: const Text('Assigned to you'),
                              )
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: OutlinedButton.icon(
                            onPressed: isNotifying
                                ? null
                                : () => _notifyUsers(row),
                            icon: isNotifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.notifications_outlined),
                            label: Text(
                              isNotifying ? 'Notifying...' : 'Notify',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  bool _actorMatchesUser(String actor) {
    final normalizedActor = actor.trim().toLowerCase();
    final role = widget.user.role.trim().toLowerCase();
    final code = widget.user.code.trim().toLowerCase();
    const actorAliases = {
      'dlr.ddd-dist-adm.bbb': 'dealer distribution admin',
      'dlr.ddd-dist-mgr.ccc': 'dealer distribution manager',
      'whs-dist-adm.mmm': 'modena warehouse distribution admin',
      'log.lll-drvr.kkk': 'third party logistics driver',
    };

    return normalizedActor == role ||
        normalizedActor == code ||
        actorAliases[normalizedActor] == role;
  }
}

class ApprovalQueuePage extends StatefulWidget {
  const ApprovalQueuePage({super.key, required this.user});

  final UserProfile user;

  @override
  State<ApprovalQueuePage> createState() => _ApprovalQueuePageState();
}

class _ApprovalQueuePageState extends State<ApprovalQueuePage> {
  late Future<List<Map<String, dynamic>>> _rowsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _loadRows();
  }

  Future<List<Map<String, dynamic>>> _loadRows() async {
    final rows = await SupabaseService.instance.fetchProductJourney();
    if (rows.isEmpty) {
      return [
        {
          'id': 'P-1001',
          'state': 'Allocated',
          'actor': 'dlr.DDD-dist-adm.BBB',
          'initiator': 'dealer distribution admin',
          'loa': 'LoA1',
          'status': 'pending',
          'approved_by': null,
        },
        {
          'id': 'P-1002',
          'state': 'Ordered',
          'actor': 'dlr.DDD-dist-mgr.CCC',
          'initiator': 'dealer distribution admin',
          'loa': 'LoA3',
          'status': 'approved',
          'approved_by': 'Dealer Manager',
        },
        {
          'id': 'P-1003',
          'state': 'Confirmed',
          'actor': 'whs-dist-adm.MMM',
          'initiator': 'modena warehouse distribution admin',
          'loa': 'LoA2',
          'status': 'pending',
          'approved_by': null,
        },
        {
          'id': 'P-1004',
          'state': 'Intransit',
          'actor': 'log.LLL-drvr.KKK',
          'initiator': 'third party logistics driver',
          'loa': 'LoA2',
          'status': 'awaiting_delivery',
          'approved_by': 'Warehouse Admin',
        },
      ];
    }
    return rows;
  }

  Future<void> _updateStatus(
    String id,
    String status, {
    String? comment,
  }) async {
    await SupabaseService.instance.createApprovalDecision(
      journeyId: id,
      decision: status,
      approverName: widget.user.name,
      approverRole: widget.user.role,
      comment: comment,
    );

    await SupabaseService.instance.updateApprovalStatus(
      id: id,
      status: status,
      approver: widget.user.name,
    );

    final rows = await _loadRows();
    if (!mounted) return;
    setState(() {
      _rowsFuture = Future.value(rows);
    });
  }

  bool _canModifyRow({required String actor, required String initiator}) {
    final userCode = widget.user.code.trim().toLowerCase();
    final userRole = widget.user.role.trim().toLowerCase();
    final normalizedActor = actor.trim().toLowerCase();
    final normalizedInitiator = initiator.trim().toLowerCase();

    return normalizedActor.contains(userCode) ||
        normalizedInitiator.contains(userRole) ||
        userRole.contains(normalizedInitiator);
  }

  void _returnToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Flow')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rowsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('No approval rows found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final id = row['id']?.toString() ?? 'N/A';
              final state = row['state']?.toString() ?? 'Unknown';
              final actor = row['actor']?.toString() ?? 'Unknown';
              final initiator =
                  row['initiator']?.toString() ??
                  row['initBy']?.toString() ??
                  'Unknown';
              final loa = row['loa']?.toString() ?? 'LoA';
              final status = row['status']?.toString() ?? 'pending';
              final canModify = _canModifyRow(
                actor: actor,
                initiator: initiator,
              );
              final commentController = TextEditingController();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: canModify ? null : Colors.grey.shade200,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$state · $id',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(label: Text(status)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Initiator: $initiator'),
                      Text('Actor: $actor'),
                      Text('LoA: $loa'),
                      if (canModify) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentController,
                          decoration: const InputDecoration(
                            labelText: 'Approval note',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _updateStatus(
                                  id,
                                  'approved',
                                  comment: commentController.text.trim(),
                                ),
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _updateStatus(
                                  id,
                                  'rejected',
                                  comment: commentController.text.trim(),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _returnToLogin,
                            icon: const Icon(Icons.block),
                            label: const Text('No action'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class JourneyScriptPage extends StatelessWidget {
  const JourneyScriptPage({
    super.key,
    required this.journey,
    required this.user,
  });

  final List<ProductJourneyStep> journey;
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Journey Script')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: journey.length,
        itemBuilder: (context, index) {
          final step = journey[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(step.state),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Initiator: ${step.initBy}'),
                  Text('Actor: ${step.actor}'),
                  Text('LoA: ${step.loa}'),
                  Text('User: ${user.name} (${user.role})'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

List<ProductJourneyStep> getMockJourney() {
  final now = DateTime.now();
  return [
    ProductJourneyStep(
      id: 'P-001',
      state: 'Allocated',
      actor: 'dlr.DDD-dist-adm.BBB',
      initBy: 'dealer distribution admin',
      loa: 'LoA1',
      timestamp: now,
    ),
    ProductJourneyStep(
      id: 'P-001',
      state: 'Ordered',
      actor: 'dlr.DDD-dist-mgr.CCC',
      initBy: 'dealer distribution admin',
      loa: 'LoA3',
      timestamp: now.add(const Duration(minutes: 5)),
    ),
    ProductJourneyStep(
      id: 'P-001',
      state: 'Confirmed',
      actor: 'whs-dist-adm.MMM',
      initBy: 'modena warehouse distribution admin',
      loa: 'LoA2',
      timestamp: now.add(const Duration(minutes: 12)),
    ),
  ];
}
