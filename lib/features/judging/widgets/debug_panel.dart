import 'package:flutter/material.dart';

/// Debug panel – zobrazí Centrifugo status a log událostí.
///
/// Otevírá se jako modální bottom sheet z JudgingScreen.
/// Zachovává stejnou funkcionalitu jako původní CompetitionDetailScreen.
class DebugPanel extends StatelessWidget {
  final String connectionStatus;
  final List<String> logEntries;

  const DebugPanel({
    super.key,
    required this.connectionStatus,
    required this.logEntries,
  });

  /// Otevře debug panel jako bottom sheet.
  static void show(
    BuildContext context, {
    required String connectionStatus,
    required List<String> logEntries,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DebugPanel(
        connectionStatus: connectionStatus,
        logEntries: logEntries,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Táhlo pro přetahování
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Nadpis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'DEBUG LOG',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${logEntries.length} záznamů',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),

            // Centrifugo status
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              width: double.infinity,
              child: Text(
                connectionStatus,
                style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontFamily: 'Courier',
                  fontSize: 11,
                ),
              ),
            ),

            const Divider(color: Colors.grey, height: 1),

            // Seznam log záznamů
            Expanded(
              child: logEntries.isEmpty
                  ? Center(
                      child: Text(
                        'Zatím žádné záznamy...',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: logEntries.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            logEntries[index],
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'Courier',
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
