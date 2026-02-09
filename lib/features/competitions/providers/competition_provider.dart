import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/competition.dart';
import '../../../core/services/api_service.dart';

// Jednoduchý provider, který zavolá API a vrátí Future
final myCompetitionsProvider = FutureProvider.autoDispose<List<Competition>>((
  ref,
) async {
  print("🔥 Provider: myCompetitionsProvider started");
  // Zde můžeme použít ApiService.
  // Pokud ho nemáš jako provider, použij Singleton: ApiService()
  final api = ApiService();
  return api.getMyCompetitions();
});
