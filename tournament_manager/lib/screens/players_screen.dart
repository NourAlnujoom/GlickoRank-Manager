import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/player.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  late Future<List<Player>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _playersFuture = ApiService.fetchPlayers();
    });
  }

  void _showAddPlayerDialog() {
    final nameCtrl = TextEditingController();
    final ratingCtrl = TextEditingController(text: "1500");
    final rdCtrl = TextEditingController(text: "350");
    final volCtrl = TextEditingController(text: "0.06");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add New Player"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: ratingCtrl, decoration: const InputDecoration(labelText: "Rating"), keyboardType: TextInputType.number),
            TextField(controller: rdCtrl, decoration: const InputDecoration(labelText: "RD"), keyboardType: TextInputType.number),
            TextField(controller: volCtrl, decoration: const InputDecoration(labelText: "Volatility"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              
              final error = await ApiService.createPlayer(
                nameCtrl.text,
                double.tryParse(ratingCtrl.text) ?? 1500,
                double.tryParse(rdCtrl.text) ?? 350,
                double.tryParse(volCtrl.text) ?? 0.06,
              );

              if (context.mounted) {
                Navigator.pop(ctx);
                if (error == null) {
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Player Added!"), backgroundColor: Colors.green));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlayerDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<List<Player>>(
        future: _playersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          final players = snapshot.data ?? [];
          if (players.isEmpty) return const Center(child: Text("No players found."));

          return ListView.builder(
            itemCount: players.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (ctx, i) {
              final p = players[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.transparent, child: Text(p.emoji, style: const TextStyle(fontSize: 24)),),

                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name, 
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(p.tier, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                  subtitle: Text("RD: ${p.rd.toStringAsFixed(1)} | Vol: ${p.vol.toStringAsFixed(3)}"),
                  trailing: Text(p.rating.toStringAsFixed(0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}