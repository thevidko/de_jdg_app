import 'package:de_jdg_app/features/competitions/providers/competition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Doporučuji přidat balíček 'intl' pro formátování data
import '../../auth/controllers/auth_controller.dart';
import '../../../core/models/competition.dart';
import '../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.surface, // Čisté pozadí podle DESIGN.md
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'DE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DanceEval',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    height: 1.1,
                  ),
                ),
                Text(
                  'JUDGE',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    letterSpacing: 1.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(myCompetitionsProvider),
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerLowest,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Vítejte, porotce",
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.fullName ?? "Neznámý uživatel",
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      "Aktivní nominace",
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            competitionsAsyncValue.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text("Chyba při načítání: $err", textAlign: TextAlign.center, style: const TextStyle(color: AppColors.onSurface)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => ref.refresh(myCompetitionsProvider),
                          child: const Text("Zkusit znovu", style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (competitions) {
                if (competitions.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text("Zatím nemáte přiřazené žádné soutěže.", style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final comp = competitions[index];
                        return _buildCompetitionCard(context, comp);
                      },
                      childCount: competitions.length,
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

  Widget _buildCompetitionCard(BuildContext context, Competition comp) {
    final dateFormatted = DateFormat('d. M. yyyy').format(comp.dateStart);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0), // The "Air" Principle (velkorysá mezera)
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompetitionDetailScreen(competitionId: comp.id.toString()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest, // #ffffff
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withOpacity(0.04), // Extrémně difuzní ambientní stín
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status badge (Design: secondary container s on-secondary textem do full-roundedness)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDC8FF), // secondary_container z DESIGN.md
                      borderRadius: BorderRadius.circular(9999), 
                    ),
                    child: const Text(
                      "AKTIVNÍ", 
                      style: TextStyle(
                        color: Color(0xFF572BA0), // on_secondary_container
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        fontFamily: 'Inter',
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Text(
                    dateFormatted,
                    style: const TextStyle(
                      color: AppColors.outline,
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                comp.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comp.location,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
