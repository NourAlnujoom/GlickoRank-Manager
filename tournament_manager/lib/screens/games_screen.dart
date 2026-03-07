import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/api_service.dart';
import '../models/player.dart';

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final TextEditingController _p1Ctrl = TextEditingController();
  final TextEditingController _p2Ctrl = TextEditingController();
  
  Key _formKey = UniqueKey(); 
  
  String? _winner;
  List<Player> _cachedPlayers = [];
  final List<String> _localGameLog = [];

  @override
  void initState() {
    super.initState();
    _refreshPlayers();
  }

  @override
  void dispose() {
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _refreshPlayers() async {
    try {
      final players = await ApiService.fetchPlayers();
      setState(() => _cachedPlayers = players);
    } catch (e) { print(e); }
  }

  Future<void> _submitGame() async {
    FocusScope.of(context).unfocus(); 

    final p1 = _p1Ctrl.text.trim();
    final p2 = _p2Ctrl.text.trim();

    if (p1 == p2 && p1.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A player cannot play against themselves!"), backgroundColor: Colors.orange));
      return;
    }

    if (p1.isEmpty || p2.isEmpty || _winner == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Data!"), backgroundColor: Colors.orange));
      return;
    }

    double res = (_winner == "Player 1") ? 1.0 : (_winner == "Player 2") ? 0.0 : 0.5;
    final error = await ApiService.addGame(p1, p2, res);
    
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game Added!"), backgroundColor: Colors.green));
      
      setState(() {
        String winText = (_winner == "Draw") ? "Draw" : "$_winner Won";
        _localGameLog.insert(0, "$p1 vs $p2 ($winText)");
        
        _p1Ctrl.clear();
        _p2Ctrl.clear();
        _winner = null;
        _formKey = UniqueKey(); 
      });
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    }
  }

  Future<void> _finishTournament() async {
    try {
      final results = await ApiService.processTournament();
      setState(() => _localGameLog.clear());
      _showResultsPopup(results);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  void _showResultsPopup(List<dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tournament Updates"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: data.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (ctx, i) {
              final item = data[i];
              double oldR = (item['old_rating'] as num).toDouble();
              double newR = (item['new_rating'] as num).toDouble();
              double diffR = newR - oldR;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("R: ${oldR.toStringAsFixed(1)} → ${newR.toStringAsFixed(1)}"),
                      Text("${diffR >= 0 ? '+' : ''}${diffR.toStringAsFixed(1)}",
                        style: TextStyle(color: diffR >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Column(
            key: _formKey,
            children: [
              TypeAheadField<Player>(
                controller: _p1Ctrl, 
                hideOnUnfocus: true,
                builder: (context, controller, focusNode) {
                  return TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: "Player 1", border: OutlineInputBorder()));
                },
                suggestionsCallback: (pattern) {
                  return _cachedPlayers.where((p) => p.name.toLowerCase().contains(pattern.toLowerCase())).toList();
                },
                itemBuilder: (context, Player p) => ListTile(
                  leading: Text(p.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(p.tier, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                onSelected: (Player p) => _p1Ctrl.text = p.name, 
              ),
              
              const SizedBox(height: 10),
              
              TypeAheadField<Player>(
                controller: _p2Ctrl,
                hideOnUnfocus: true,
                builder: (context, controller, focusNode) {
                  return TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: "Player 2", border: OutlineInputBorder()));
                },
                suggestionsCallback: (pattern) {
                  return _cachedPlayers.where((p) => p.name.toLowerCase().contains(pattern.toLowerCase()))
                      .where((p) => p.name != _p1Ctrl.text).toList();
                },
                itemBuilder: (context, Player p) => ListTile(
                  leading: Text(p.emoji, style: const TextStyle(fontSize: 22)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(p.tier, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                onSelected: (Player p) => _p2Ctrl.text = p.name,
              ),
              
              const SizedBox(height: 10),
              
              DropdownButtonFormField<String>(
                value: _winner,
                hint: const Text("Who Won?"),
                items: ["Player 1", "Player 2", "Draw"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _winner = v),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _submitGame, icon: const Icon(Icons.add), label: const Text("Add Game to Queue"))),
          const Divider(height: 30, thickness: 2),
          Row(children: [const Icon(Icons.list_alt, color: Colors.grey), const SizedBox(width: 8), Text("Games in Queue: ${_localGameLog.length}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: _localGameLog.isEmpty 
                ? const Center(child: Text("No games added yet", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _localGameLog.length,
                    itemBuilder: (ctx, i) => ListTile(dense: true, leading: Text("${_localGameLog.length - i}."), title: Text(_localGameLog[i])),
                  ),
            ),
          ),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _finishTournament, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), child: const Text("FINISH TOURNAMENT"))),
        ],
      ),
    );
  }
}