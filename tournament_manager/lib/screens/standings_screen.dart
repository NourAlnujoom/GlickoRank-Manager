import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/player.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  late Future<List<Player>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _standingsFuture = _loadSortedPlayers();
  }

  Future<List<Player>> _loadSortedPlayers() async {
    List<Player> players = await ApiService.fetchPlayers();
    players.sort((a, b) => b.rating.compareTo(a.rating));
    return players;
  }

  Future<void> _refresh() async {
    setState(() {
      _standingsFuture = _loadSortedPlayers();
    });
  }

 @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Player>>(
        future: _standingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final players = snapshot.data!;
          final List<String> tierOrder = ['Grandmaster', 'Master', 'Challenger', 'Rookie'];
          List<Widget> listItems = [];

          for (String tier in tierOrder) {
            var tierPlayers = players.where((p) => p.tier.toLowerCase() == tier.toLowerCase()).toList();
            
            if (tierPlayers.isNotEmpty) {
              listItems.add(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.indigo.withOpacity(0.1),
                  child: Row(
                    children: [
                      Text(tierPlayers.first.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Text("${tier}s", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.indigo)),
                    ],
                  ),
                )
              );

              for (int i = 0; i < tierPlayers.length; i++) {
                final p = tierPlayers[i];
                listItems.add(
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: ListTile(
                      leading: Text(
                        "#${i + 1}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(
                        p.rating.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  )
                );
              }
            }
          }

          if (listItems.isEmpty) return const Center(child: Text("No standings available."));

          return ListView(children: listItems);
        },
      ),
    );
  }
}