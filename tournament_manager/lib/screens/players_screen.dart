import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/player.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  List<Player> _players = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    setState(() => _isLoading = true);
    try {
      final players = await ApiService.fetchPlayers();
      setState(() {
        _players = players;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading players: $e'), backgroundColor: Colors.red));
    }
  }

  // --- ADD PLAYER (Feature 2: Default RD to 200) ---
  void _showAddPlayerDialog() {
    final nameCtrl = TextEditingController();
    final ratingCtrl = TextEditingController(text: "1500.0");
    final rdCtrl = TextEditingController(text: "200.0"); // Default fixed to 200!
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
              // Note: You might need to add a small addPlayer method to your api_service.dart if you haven't already!
              final response = await http.post(
                Uri.parse('${ApiService.baseUrl}/players'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "name": nameCtrl.text,
                  "rating": double.tryParse(ratingCtrl.text) ?? 1500.0,
                  "rd": double.tryParse(rdCtrl.text) ?? 200.0,
                  "vol": double.tryParse(volCtrl.text) ?? 0.06
                })
              );

              if (context.mounted) Navigator.pop(ctx);
              _fetchPlayers();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // --- THE MINI DETAILS WINDOW (Feature 1) ---
  void _showPlayerDetails(Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(player.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(child: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow("Tier:", player.tier),
            _buildDetailRow("Rating:", player.rating.toStringAsFixed(1)),
            _buildDetailRow("RD:", player.rd.toStringAsFixed(1)),
            _buildDetailRow("Volatility:", player.vol.toStringAsFixed(3)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // TRASH CAN BUTTON
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 28),
            tooltip: "Delete Player",
            onPressed: () {
              Navigator.pop(ctx); // Close the details window
              _confirmDelete(player); // Open the confirmation window
            },
          ),
          // PEN BUTTON
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.indigo, size: 28),
            tooltip: "Edit Player",
            onPressed: () {
              Navigator.pop(ctx); // Close the details window
              _showEditDialog(player); // Open the edit form
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // --- DELETE CONFIRMATION ---
  void _confirmDelete(Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Player?"),
        content: Text("Are you sure you want to permanently delete ${player.name}? This cannot be undone.", style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await ApiService.deletePlayer(player.name);
              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${player.name} deleted."), backgroundColor: Colors.green));
                _fetchPlayers();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
              }
            },
            child: const Text("Yes, Delete"),
          ),
        ],
      ),
    );
  }

  // --- EDIT FORM ---
  void _showEditDialog(Player player) {
    final nameCtrl = TextEditingController(text: player.name);
    final ratingCtrl = TextEditingController(text: player.rating.toString());
    final rdCtrl = TextEditingController(text: player.rd.toString());
    final volCtrl = TextEditingController(text: player.vol.toString());
    
    // Dropdown list
    final List<String> tiers = ['Grandmaster', 'Master', 'Challenger', 'Rookie'];
    String selectedTier = player.tier;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // StatefulBuilder allows dropdowns to update inside a dialog
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Edit ${player.name}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Player Name")),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ratingCtrl, 
                    decoration: const InputDecoration(labelText: "Rating"), 
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      // Auto-update tier if they type a new rating
                      double? r = double.tryParse(val);
                      if (r != null) {
                        String newTier = 'Rookie';
                        if (r >= 1900) newTier = 'Grandmaster';
                        else if (r >= 1700) newTier = 'Master';
                        else if (r >= 1500) newTier = 'Challenger';
                        if (selectedTier != newTier) setState(() => selectedTier = newTier);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedTier,
                    decoration: const InputDecoration(labelText: "Tier"),
                    items: tiers.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedTier = val;
                          // Auto-update rating if they pick a tier
                          if (val == 'Grandmaster') ratingCtrl.text = '1900.0';
                          else if (val == 'Master') ratingCtrl.text = '1700.0';
                          else if (val == 'Challenger') ratingCtrl.text = '1500.0';
                          else if (val == 'Rookie') ratingCtrl.text = '1300.0';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: rdCtrl, decoration: const InputDecoration(labelText: "RD"), keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: volCtrl, decoration: const InputDecoration(labelText: "Volatility"), keyboardType: TextInputType.number)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                onPressed: () async {
                  Map<String, dynamic> updates = {};
                  if (nameCtrl.text != player.name) updates['new_name'] = nameCtrl.text;
                  updates['rating'] = double.tryParse(ratingCtrl.text) ?? player.rating;
                  updates['rd'] = double.tryParse(rdCtrl.text) ?? player.rd;
                  updates['vol'] = double.tryParse(volCtrl.text) ?? player.vol;
                  updates['tier'] = selectedTier;

                  final error = await ApiService.updatePlayer(player.name, updates);
                  Navigator.pop(ctx);
                  
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Player updated!"), backgroundColor: Colors.green));
                    _fetchPlayers();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                  }
                },
                child: const Text("Save Changes"),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPlayerDialog,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final player = _players[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Text(player.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(player.tier),
                    trailing: Text(player.rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () => _showPlayerDetails(player), // TAPPING OPENS THE MINI WINDOW!
                  ),
                );
              },
            ),
    );
  }
}