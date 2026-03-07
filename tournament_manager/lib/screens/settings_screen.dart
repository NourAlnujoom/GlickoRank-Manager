import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<dynamic>> _tiersFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _tiersFuture = ApiService.fetchTiers();
    });
  }

  Future<void> _handleUpdate(String tier, String r, String rd, String v) async {
    double rating = double.tryParse(r) ?? 1500;
    double newRd = double.tryParse(rd) ?? 200;
    double newVol = double.tryParse(v) ?? 0.06;

    final error = await ApiService.updateTier(tier, rating, newRd, newVol);
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$tier baseline updated!"), backgroundColor: Colors.green));
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleReset(String tier) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Reset $tier?"),
        content: Text("This will force ALL $tier players back to the baseline stats. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("RESET"),
          )
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final error = await ApiService.resetTier(tier);
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$tier players reset!"), backgroundColor: Colors.orange));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleUndo() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Undo Last Tournament?"),
        content: const Text("This will revert ALL player ratings back to exactly how they were before the last tournament was processed. This action cannot be reversed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("UNDO TOURNAMENT"),
          )
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    final error = await ApiService.undoLastTournament();
    if (mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tournament Undone! Ratings restored."), backgroundColor: Colors.green));
        _refresh(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 24.0, bottom: 16.0), 
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              icon: const Icon(Icons.undo),
              label: const Text("UNDO LAST TOURNAMENT", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _handleUndo,
            ),
          ),
        ),
        
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _tiersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
              
              final tiers = snapshot.data ?? [];
              tiers.sort((a, b) => (a['rating'] as num).compareTo(b['rating'] as num));

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: tiers.length,
                itemBuilder: (ctx, i) {
                  final t = tiers[i];
                  
                  final rCtrl = TextEditingController(text: t['rating'].toString());
                  final rdCtrl = TextEditingController(text: t['rd'].toString());
                  final vCtrl = TextEditingController(text: t['vol'].toString());

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['group_tier'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: rCtrl, decoration: const InputDecoration(labelText: "Base Rating", border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: rdCtrl, decoration: const InputDecoration(labelText: "Base RD", border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: vCtrl, decoration: const InputDecoration(labelText: "Base Vol", border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () => _handleReset(t['group_tier']), 
                                icon: const Icon(Icons.warning, color: Colors.red), 
                                label: const Text("Reset Players", style: TextStyle(color: Colors.red)),
                              ),
                              ElevatedButton(
                                onPressed: () => _handleUpdate(t['group_tier'], rCtrl.text, rdCtrl.text, vCtrl.text),
                                child: const Text("Save Baseline"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}