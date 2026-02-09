import 'package:de_jdg_app/features/competitions/providers/competition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Doporučuji přidat balíček 'intl' pro formátování data
import '../../auth/controllers/auth_controller.dart';
import '../../../core/models/competition.dart';
import 'competition_detail_screen.dart';

class CompetitionsScreen extends ConsumerWidget {
  const CompetitionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Získáme data o přihlášeném uživateli
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    // 2. Sledujeme stav načítání soutěží
    final competitionsAsyncValue = ref.watch(myCompetitionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Taneční soutěže"),
        actions: [
          // Tlačítko pro odhlášení
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HLAVIČKA S UŽIVATELEM ---
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vítejte, porotce",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user?.fullName ?? "Neznámý uživatel",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // --- SEZNAM SOUTĚŽÍ ---
          Expanded(
            child: competitionsAsyncValue.when(
              // 1. Stav načítání
              loading: () => const Center(child: CircularProgressIndicator()),

              // 2. Stav chyby
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Chyba při načítání: $err",
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(myCompetitionsProvider),
                        child: const Text("Zkusit znovu"),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Data načtena
              data: (competitions) {
                if (competitions.isEmpty) {
                  return const Center(
                    child: Text("Zatím nemáte přiřazené žádné soutěže."),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(myCompetitionsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: competitions.length,
                    itemBuilder: (context, index) {
                      final comp = competitions[index];
                      return _buildCompetitionCard(context, comp);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitionCard(BuildContext context, Competition comp) {
    // Formátování data (vyžaduje intl balíček, jinak použij comp.dateStart.toString())
    final dateFormatted = DateFormat('d. M. yyyy').format(comp.dateStart);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CompetitionDetailScreen(competitionId: comp.id.toString()),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge (jednoduchá ukázka)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Aktivní", // Zde by byla logika podle status ID
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    dateFormatted,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                comp.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    comp.location,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
