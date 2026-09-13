import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodvision/core/config/environment.dart';
import 'package:foodvision/core/auth/auth_service.dart';
import 'package:foodvision/core/services/app_log_service.dart';
import 'package:foodvision/core/services/local_ai_service.dart';
import 'package:foodvision/features/auth/auth_provider.dart';
import 'package:foodvision/app/router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _consentGranted = false;
  bool _consentLoaded = false;
  bool _uploadingLogs = false;
  LogUploadScope _logScope = LogUploadScope.today;
  DateTime? _startDate;
  DateTime? _endDate;

  // Local AI (Ollama) state
  bool _localAiEnabled = true;
  late final TextEditingController _localAiUrlController;
  late final TextEditingController _localAiModelController;
  bool _testingLocalAi = false;
  String? _localAiStatus;
  bool? _localAiReachable;
  List<String> _availableLocalModels = [];

  // Regional & Authorization state
  bool _deepLocalAiAllowed = false;
  bool _checkingDeepLocalAi = true;
  String _selectedLocale = 'en_MY';
  String _selectedCurrency = 'MYR';
  String _selectedUnitSystem = 'metric';

  @override
  void initState() {
    super.initState();
    _localAiUrlController = TextEditingController(text: LocalAiService.kDefaultUrl);
    _localAiModelController = TextEditingController(text: LocalAiService.kDefaultModel);
    _loadConsent();
    _loadLocalAiSettings();
    _checkDeepLocalAiPermission();
    _loadRegionalPreferences();
  }

  @override
  void dispose() {
    _localAiUrlController.dispose();
    _localAiModelController.dispose();
    super.dispose();
  }

  Future<void> _checkDeepLocalAiPermission() async {
    final auth = ref.read(authServiceProvider);
    final allowed = await auth.canAccessDeepLocalAi();
    if (!mounted) return;
    setState(() {
      _deepLocalAiAllowed = allowed;
      _checkingDeepLocalAi = false;
    });
  }

  Future<void> _loadRegionalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedLocale = prefs.getString('user_locale') ?? 'en_MY';
      _selectedCurrency = prefs.getString('user_currency') ?? 'MYR';
      _selectedUnitSystem = prefs.getString('user_unit_system') ?? 'metric';
    });
  }

  Future<void> _saveRegionalPreferences({
    String? locale,
    String? currency,
    String? unitSystem,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale != null) {
      await prefs.setString('user_locale', locale);
      setState(() => _selectedLocale = locale);
    }
    if (currency != null) {
      await prefs.setString('user_currency', currency);
      setState(() => _selectedCurrency = currency);
    }
    if (unitSystem != null) {
      await prefs.setString('user_unit_system', unitSystem);
      setState(() => _selectedUnitSystem = unitSystem);
    }
  }

  Future<void> _loadLocalAiSettings() async {
    final localAi = ref.read(localAiServiceProvider);
    final enabled = await localAi.isEnabled();
    final url = await localAi.getBaseUrl();
    final model = await localAi.getSelectedModel();
    if (!mounted) return;
    setState(() {
      _localAiEnabled = enabled;
      _localAiUrlController.text = url;
      _localAiModelController.text = model;
    });
  }

  Future<void> _testLocalAiConnection() async {
    setState(() {
      _testingLocalAi = true;
      _localAiStatus = null;
      _localAiReachable = null;
    });

    final localAi = ref.read(localAiServiceProvider);
    final url = _localAiUrlController.text.trim();
    final reachable = await localAi.checkReachability(urlOverride: url);
    List<String> models = [];
    if (reachable) {
      models = await localAi.fetchModels(urlOverride: url);
      await localAi.setBaseUrl(url);
      await localAi.setEnabled(_localAiEnabled);
      if (_localAiModelController.text.isNotEmpty) {
        await localAi.setSelectedModel(_localAiModelController.text.trim());
      }
    }

    if (!mounted) return;
    setState(() {
      _testingLocalAi = false;
      _localAiReachable = reachable;
      _availableLocalModels = models;
      if (reachable) {
        _localAiStatus = 'Connected to Ollama! Found ${models.length} model(s).';
      } else {
        _localAiStatus = 'Could not connect to $url on LAN. Verify Ollama is running with OLLAMA_HOST=0.0.0.0.';
      }
    });
  }

  Future<void> _loadConsent() async {
    final granted = await AppLogService.isUploadConsentGranted();
    if (!mounted) return;
    setState(() {
      _consentGranted = granted;
      _consentLoaded = true;
    });
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDate: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  String _fmtDate(DateTime? d) => d == null ? "Select" : d.toIso8601String().split('T').first;

  bool get _canUpload {
    if (!_consentGranted || _uploadingLogs) return false;
    if (_logScope != LogUploadScope.range) return true;
    if (_startDate == null || _endDate == null) return false;
    return !_endDate!.isBefore(_startDate!);
  }

  @override
  Widget build(BuildContext context) {
    final currentEnvironment = ref.watch(environmentProvider);
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    final authService = ref.watch(authServiceProvider);
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Environment Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Environment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select which backend to connect to for testing',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Live (Cloud) Option
                    ListTile(
                      title: const Text('Live (Cloud)'),
                      subtitle: const Text('https://nutrilens-api-2ajzj2dbrq-uc.a.run.app'),
                      // ignore: deprecated_member_use
                      leading: Radio<AppEnvironment>(
                        value: AppEnvironment.live,
                        // ignore: deprecated_member_use
                        groupValue: currentEnvironment,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(environmentProvider.notifier)
                                .setEnvironment(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Switched to Live mode. Restart app for changes to take effect.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Debug (Localhost) Option
                    ListTile(
                      title: const Text('Debug (Localhost)'),
                      subtitle: const Text('http://10.0.2.2:8000 (Android Emulator)'),
                      // ignore: deprecated_member_use
                      leading: Radio<AppEnvironment>(
                        value: AppEnvironment.debug,
                        // ignore: deprecated_member_use
                        groupValue: currentEnvironment,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          if (value != null) {
                            ref
                                .read(environmentProvider.notifier)
                                .setEnvironment(value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Switched to Debug mode. Restart app for changes to take effect.',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        '💡 Tip: For physical Android devices, change the localhost IP to your computer\'s IP address (e.g., 192.168.0.10:8000) in lib/core/config/environment.dart',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Nutritional Goals & Profile Section
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person),
                ),
                title: const Text(
                  'Profile & Nutrition Goals',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Set calorie & macro targets, dietary restrictions, and reminders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.profile),
              ),
            ),
            const SizedBox(height: 16),
            // Preferences & Localization Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          child: Icon(Icons.language),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preferences & Localization',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Display language, currency, and measurement units',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLocale,
                      decoration: const InputDecoration(
                        labelText: 'App Language & Locale',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.translate),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en_MY', child: Text('English (Malaysia - en_MY)')),
                        DropdownMenuItem(value: 'ms_MY', child: Text('Bahasa Melayu (ms_MY)')),
                        DropdownMenuItem(value: 'en_SG', child: Text('English (Singapore - en_SG)')),
                        DropdownMenuItem(value: 'en_US', child: Text('English (US - en_US)')),
                        DropdownMenuItem(value: 'en_GB', child: Text('English (UK - en_GB)')),
                      ],
                      onChanged: (val) {
                        if (val != null) _saveRegionalPreferences(locale: val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCurrency,
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'MYR', child: Text('MYR (RM)')),
                              DropdownMenuItem(value: 'SGD', child: Text('SGD (S\$)')),
                              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                              DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                            ],
                            onChanged: (val) {
                              if (val != null) _saveRegionalPreferences(currency: val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedUnitSystem,
                            decoration: const InputDecoration(
                              labelText: 'Unit System',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'metric', child: Text('Metric (g, ml)')),
                              DropdownMenuItem(value: 'imperial', child: Text('Imperial (oz, fl oz)')),
                            ],
                            onChanged: (val) {
                              if (val != null) _saveRegionalPreferences(unitSystem: val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Local AI (Ollama) Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _deepLocalAiAllowed ? Colors.indigo : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.hub),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Local AI Agent (Ollama)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _deepLocalAiAllowed
                                    ? 'Deep multimodal second opinion on your LAN'
                                    : 'Feature requires administrator permission',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (_checkingDeepLocalAi)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (!_deepLocalAiAllowed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Restricted',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          Switch(
                            value: _localAiEnabled,
                            onChanged: (val) async {
                              setState(() => _localAiEnabled = val);
                              await ref.read(localAiServiceProvider).setEnabled(val);
                            },
                          ),
                      ],
                    ),
                    if (!_checkingDeepLocalAi && !_deepLocalAiAllowed) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Deep Local AI Evaluation is currently disabled for your account. NutriLens is operating strictly with cloud vision (Gemini). An administrator can grant you access in Web User Management.',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_deepLocalAiAllowed && _localAiEnabled) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _localAiUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Ollama Host Endpoint',
                          hintText: 'http://<host-ip>:11434',
                          helperText: 'Set any LAN IP or hostname (e.g. http://192.168.0.200:11434)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lan),
                        ),
                        onChanged: (val) {
                          ref.read(localAiServiceProvider).setBaseUrl(val);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_availableLocalModels.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _availableLocalModels.contains(_localAiModelController.text)
                              ? _localAiModelController.text
                              : _availableLocalModels.first,
                          decoration: const InputDecoration(
                            labelText: 'Installed Vision Model',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.model_training),
                          ),
                          items: _availableLocalModels
                              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _localAiModelController.text = val;
                              ref.read(localAiServiceProvider).setSelectedModel(val);
                            }
                          },
                        )
                      else
                        TextField(
                          controller: _localAiModelController,
                          decoration: const InputDecoration(
                            labelText: 'Vision Model Name',
                            hintText: 'llama3.2-vision',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.model_training),
                          ),
                          onChanged: (val) {
                            ref.read(localAiServiceProvider).setSelectedModel(val);
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testingLocalAi ? null : _testLocalAiConnection,
                          icon: _testingLocalAi
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check),
                          label: Text(_testingLocalAi ? 'Pinging Ollama...' : 'Test LAN Connection'),
                        ),
                      ),
                      if (_localAiStatus != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _localAiReachable == true
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _localAiReachable == true
                                  ? Colors.green.shade300
                                  : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _localAiReachable == true ? Icons.check_circle : Icons.error,
                                size: 16,
                                color: _localAiReachable == true ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _localAiStatus!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _localAiReachable == true
                                        ? Colors.green.shade900
                                        : Colors.red.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Account Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (currentUser != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email: ${currentUser.email}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'User ID: ${currentUser.uid}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await ref
                                    .read(authNotifierProvider.notifier)
                                    .signOut();
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Sign Out'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const Text('Not signed in'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // App Info Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Info',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current Environment:'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: currentEnvironment == AppEnvironment.live
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentEnvironment.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentEnvironment == AppEnvironment.live
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('API URL:'),
                        Expanded(
                          child: Text(
                            currentEnvironment.apiBaseUrl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diagnostics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload app logs to backend for troubleshooting.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (!_consentLoaded)
                      const LinearProgressIndicator()
                    else
                      SwitchListTile(
                        value: _consentGranted,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Participate in improving the app'),
                        subtitle: const Text(
                          'Allow sending diagnostic logs when you choose to upload them.',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: (value) async {
                          await AppLogService.setUploadConsent(value);
                          if (!mounted) return;
                          setState(() => _consentGranted = value);
                        },
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LogUploadScope>(
                      initialValue: _logScope,
                      decoration: const InputDecoration(
                        labelText: 'Log scope',
                        border: OutlineInputBorder(),
                      ),
                      items: LogUploadScope.values
                          .map((scope) => DropdownMenuItem(
                                value: scope,
                                child: Text(scope.label),
                              ))
                          .toList(),
                      onChanged: _consentGranted
                          ? (value) {
                              if (value == null) return;
                              setState(() => _logScope = value);
                            }
                          : null,
                    ),
                    if (_logScope == LogUploadScope.range) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _consentGranted ? () => _pickDate(start: true) : null,
                              child: Text('Start: ${_fmtDate(_startDate)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _consentGranted ? () => _pickDate(start: false) : null,
                              child: Text('End: ${_fmtDate(_endDate)}'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _canUpload
                            ? () async {
                                setState(() => _uploadingLogs = true);
                                try {
                                  final result = await AppLogService.uploadLogs(
                                    baseUrl: apiBaseUrl,
                                    authService: authService,
                                    environment: currentEnvironment.displayName,
                                    scope: _logScope,
                                    startDate: _startDate,
                                    endDate: _endDate,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Logs uploaded: ${result['log_id']}'),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Log upload failed: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _uploadingLogs = false);
                                  }
                                }
                              }
                            : null,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(_uploadingLogs ? 'Uploading...' : 'Upload Diagnostic Logs'),
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
