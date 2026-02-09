import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:centrifuge/centrifuge.dart';
import '../../realtime/providers/centrifugo_providers.dart';

class CompetitionDetailScreen extends ConsumerStatefulWidget {
  final String competitionId;

  const CompetitionDetailScreen({super.key, required this.competitionId});

  @override
  ConsumerState<CompetitionDetailScreen> createState() =>
      _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState
    extends ConsumerState<CompetitionDetailScreen> {
  Subscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Inicializace odběru až po vykreslení
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtime();
    });
  }

  Future<void> _setupRealtime() async {
    final centrifugo = ref.read(centrifugoServiceProvider);

    // Název kanálu dle tvé tabulky
    final channelName = 'judges:${widget.competitionId}';

    // Subscribe (uvnitř se automaticky zavolá API pro token)
    _subscription = await centrifugo.subscribe(channelName);

    // Poslouchání zpráv
    _subscription?.publication.listen((event) {
      final payload = jsonDecode(utf8.decode(event.data));
      final eventName = payload['event'];
      final eventData = payload['data'];

      _addLog("📩 PŘIŠLA NOTIFIKACE: $eventName");
      print("🔔 PŘIŠLA NOTIFIKACE: $eventName");

      if (eventName == 'ROUND_START') {
        _handleRoundStart(eventData);
      }
    });

    _subscription?.join.listen((event) {
      _addLog("👋 User joined: ${event.user}");
    });

    _subscription?.leave.listen((event) {
      _addLog("qv User left: ${event.user}");
    });
  }

  void _handleRoundStart(dynamic data) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Začíná kolo: ${data['name']}"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Probíhá soutěž")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            child: StreamBuilder<String>(
              stream: ref
                  .read(centrifugoServiceProvider)
                  .statusStream
                  .distinct(),
              initialData: ref.read(centrifugoServiceProvider).currentStatus,
              builder: (context, snapshot) {
                final status = snapshot.data ?? "Zatím žádný status...";
                return Text(
                  status,
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                );
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Log událostí:"),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _logs[index],
                    style: const TextStyle(fontSize: 12),
                  ),
                  leading: const Icon(Icons.arrow_right, size: 16),
                  dense: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  final List<String> _logs = [];

  void _addLog(String log) {
    if (!mounted) return;
    setState(() {
      _logs.insert(
        0,
        "${DateTime.now().toIso8601String().split('T').last.split('.').first} - $log",
      );
    });
  }
}
