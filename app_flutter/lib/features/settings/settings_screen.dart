import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/environment.dart';
import '../../core/auth/auth_service.dart';
import '../../core/services/app_log_service.dart';
import '../auth/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadConsent();
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
                      leading: Radio<AppEnvironment>(
                        value: AppEnvironment.live,
                        groupValue: currentEnvironment,
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
                      leading: Radio<AppEnvironment>(
                        value: AppEnvironment.debug,
                        groupValue: currentEnvironment,
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
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
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
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
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
                      value: _logScope,
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
