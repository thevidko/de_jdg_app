import 'package:de_jdg_app/core/services/api_service.dart';
import 'package:de_jdg_app/core/services/discovery_service.dart';
import 'package:de_jdg_app/core/services/storage_service.dart';
import 'package:de_jdg_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _discovery = DiscoveryService();
  final _manualUrlController = TextEditingController();
  final _manualWsController = TextEditingController();

  bool _isScanning = false;
  bool _isVerifying = false;
  List<DiscoveredBackend> _backends = [];

  // url → HealthResult (null = ještě neověřeno)
  final Map<String, HealthResult?> _health = {};

  String? _scanError;
  String? _selectError;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _manualUrlController.dispose();
    _manualWsController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanError = null;
      _backends = [];
      _health.clear();
      _selectError = null;
    });
    try {
      final results = await _discovery.discover();
      if (!mounted) return;
      setState(() {
        _backends = results;
        _isScanning = false;
      });
      // Po scanu automaticky ověříme každý nalezený backend
      _verifyAll(results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanError = 'Skenování selhalo: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _verifyAll(List<DiscoveredBackend> backends) async {
    for (final b in backends) {
      if (!mounted) return;
      final result = await _discovery.verifyBackend(b.url);
      if (!mounted) return;
      setState(() => _health[b.url] = result);
    }
  }

  Future<void> _selectBackend(DiscoveredBackend backend) async {
    setState(() {
      _selectError = null;
      _isVerifying = true;
    });

    // Ověříme živost serveru (nebo použijeme výsledek z cache)
    final health = _health[backend.url] ?? await _discovery.verifyBackend(backend.url);
    if (!mounted) return;

    if (!health.reachable) {
      setState(() {
        _health[backend.url] = health;
        _selectError = 'Server ${backend.url} není dostupný.';
        _isVerifying = false;
      });
      return;
    }

    await _save(backend.url, backend.wsUrl);
  }

  Future<void> _saveManual() async {
    final url = _manualUrlController.text.trim();
    final ws = _manualWsController.text.trim();
    if (url.isEmpty || ws.isEmpty) {
      setState(() => _selectError = 'Vyplňte obě URL.');
      return;
    }

    setState(() {
      _selectError = null;
      _isVerifying = true;
    });

    final health = await _discovery.verifyBackend(url);
    if (!mounted) return;

    if (!health.reachable) {
      setState(() {
        _selectError = 'Server $url není dostupný (zkuste /up nebo /health).';
        _isVerifying = false;
      });
      return;
    }

    await _save(url, ws);
  }

  Future<void> _save(String url, String wsUrl) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setBackendUrl(url);
    await storage.setWsUrl(wsUrl);
    ApiService().updateUrls(url, wsUrl);
    if (mounted) context.pop();
  }

  Future<void> _clearBackend() async {
    final storage = ref.read(storageServiceProvider);
    await storage.clearBackendConfig();
    ApiService().updateUrls(
      'http://localhost:8000/api/v1',
      'ws://localhost:8010/connection/websocket',
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = ref.read(storageServiceProvider).getBackendUrl();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Připojení k serveru',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentServerCard(url: currentUrl, onDisconnect: _clearBackend),
                const SizedBox(height: 28),

                // --- Sekce: Automatické vyhledávání ---
                Row(
                  children: [
                    const Text(
                      'AUTOMATICKÉ VYHLEDÁVÁNÍ',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: (_isScanning || _isVerifying) ? null : _startScan,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Skenovat znovu'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isScanning)
                  const _ScanningIndicator()
                else if (_scanError != null)
                  _ErrorCard(message: _scanError!)
                else if (_backends.isEmpty)
                  const _EmptyCard()
                else
                  ..._backends.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BackendCard(
                          backend: b,
                          isSelected: currentUrl == b.url,
                          health: _health[b.url],
                          onSelect: _isVerifying ? null : () => _selectBackend(b),
                        ),
                      )),

                const SizedBox(height: 32),

                // --- Sekce: Ruční zadání ---
                const Text(
                  'RUČNÍ ZADÁNÍ',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                _ManualInputCard(
                  urlController: _manualUrlController,
                  wsController: _manualWsController,
                  onSave: _isVerifying ? null : _saveManual,
                ),

                // --- Chyba výběru ---
                if (_selectError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: _selectError!),
                ],
              ],
            ),
          ),

          // Overlay spinner při ověřování
          if (_isVerifying)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text('Ověřuji dostupnost…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Widgets ────────────────────────────────────────────────────────────────

class _CurrentServerCard extends StatelessWidget {
  final String? url;
  final VoidCallback onDisconnect;

  const _CurrentServerCard({required this.url, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    final isConnected = url != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off_outlined,
            color: isConnected ? AppColors.primary : AppColors.inverseOnSurface,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Aktuálně připojeno' : 'Není vybrán server',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected ? AppColors.primary : AppColors.inverseOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(height: 2),
                  Text(
                    Uri.parse(url!).host,
                    style: const TextStyle(fontSize: 13, color: AppColors.onSurface),
                  ),
                ],
              ],
            ),
          ),
          if (isConnected)
            TextButton(
              onPressed: onDisconnect,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: const Text('Odpojit'),
            ),
        ],
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 16),
          Text('Skenování sítě…',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, color: AppColors.inverseOnSurface, size: 32),
          SizedBox(height: 12),
          Text('Žádný server nenalezen',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text(
            'Ujistěte se, že jste na stejné Wi-Fi síti\njako server a že běží discovery:serve.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.inverseOnSurface, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _BackendCard extends StatelessWidget {
  final DiscoveredBackend backend;
  final bool isSelected;
  final HealthResult? health;
  final VoidCallback? onSelect;

  const _BackendCard({
    required this.backend,
    required this.isSelected,
    required this.health,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isReachable = health?.reachable ?? false;
    final isChecking = health == null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dns_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      backend.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _HealthBadge(health: health),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Uri.parse(backend.url).host,
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
          else if (!isChecking && isReachable)
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
                elevation: 0,
              ),
              child: const Text('Vybrat'),
            )
          else if (!isChecking && !isReachable)
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.inverseOnSurface, size: 22),
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final HealthResult? health;
  const _HealthBadge({required this.health});

  @override
  Widget build(BuildContext context) {
    if (health == null) {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.inverseOnSurface),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: health!.reachable
            ? Colors.green.withValues(alpha: 0.12)
            : AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        health!.reachable ? 'online' : 'offline',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: health!.reachable ? Colors.green : AppColors.error,
        ),
      ),
    );
  }
}

class _ManualInputCard extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController wsController;
  final VoidCallback? onSave;

  const _ManualInputCard({
    required this.urlController,
    required this.wsController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: urlController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'API URL',
              hintText: 'http://192.168.x.x:8000/api/v1',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: wsController,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'WebSocket URL',
              hintText: 'ws://192.168.x.x:8010/connection/websocket',
              prefixIcon: Icon(Icons.swap_horiz),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.outlineVariant,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),
            child: const Text('Ověřit a uložit',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
