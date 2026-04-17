import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isUploading = false;

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
    } catch (e) { 
      print(e); 
    }
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

  Future<void> _pickAndUploadExcel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        var response = await ApiService.uploadTournamentExcel(result.files.single.path!);
        
        List validGames = response['valid_games'] ?? [];
        List conflicts = response['conflicts'] ?? [];
        List errors = response['errors'] ?? [];

        setState(() {
          _isUploading = false;
        });

        if (errors.isNotEmpty) {
          _showErrorDialog(errors);
          return;
        }

        if (conflicts.isNotEmpty) {
          _showConflictResolver(conflicts, validGames);
        } else {
          _addToQueue(validGames);
        }

      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showErrorDialog(List errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excel Formatting Errors"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) => Text("❌ ${errors[index]}"),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _showConflictResolver(List conflicts, List validGames) {
    showDialog(
      context: context,
      barrierDismissible: false, // Forces the user to resolve or cancel
      builder: (context) => TypoResolverWizard(
        conflicts: conflicts,
        validGames: validGames,
        allPlayers: _cachedPlayers,
        onFinished: (List newlyResolvedGames) {
          validGames.addAll(newlyResolvedGames);
          _addToQueue(validGames);
        },
      ),
    );
  }

  void _addToQueue(List validGames) async {
    for (var game in validGames) {
      String p1 = game['player1'];
      String p2 = game['player2'];
      double score = game['score'];
      String winner = game['winner'];

      final error = await ApiService.addGame(p1, p2, score);
      
      if (error == null) {
        String winText = (winner == "Draw") ? "Draw" : "$winner Won";
        _localGameLog.insert(0, "$p1 vs $p2 ($winText)");
      } else {
        print("Error adding game: $error");
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully queued ${validGames.length} games!'), backgroundColor: Colors.green),
    );
    setState(() {});
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

          // Excel Upload Button
          IconButton(
            icon: _isUploading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file, color: Colors.green, size: 32),
            tooltip: "Upload Excel Tournament",
            onPressed: _isUploading ? null : _pickAndUploadExcel,
          ),
          
          const SizedBox(height: 10),
          
          SizedBox(
            width: double.infinity, 
            child: ElevatedButton.icon(
              onPressed: _submitGame, 
              icon: const Icon(Icons.add), 
              label: const Text("Add Game to Queue")
            )
          ),
          
          const Divider(height: 30, thickness: 2),
          
          Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.grey), 
              const SizedBox(width: 8), 
              Text("Games in Queue: ${_localGameLog.length}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            ]
          ),
          
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
          
          SizedBox(
            width: double.infinity, 
            height: 50, 
            child: ElevatedButton(
              onPressed: _finishTournament, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), 
              child: const Text("FINISH TOURNAMENT")
            )
          ),
        ],
      ),
    );
  }
} // <-- This brace closes _GamesScreenState properly.

// --- The Wizard is now completely outside the main state class ---

class TypoResolverWizard extends StatefulWidget {
  final List conflicts;
  final List validGames;
  final List<Player> allPlayers;
  final Function(List) onFinished;

  const TypoResolverWizard({
    super.key, 
    required this.conflicts, 
    required this.validGames, 
    required this.allPlayers, 
    required this.onFinished
  });

  @override
  State<TypoResolverWizard> createState() => _TypoResolverWizardState();
}

class _TypoResolverWizardState extends State<TypoResolverWizard> {
  int _currentIndex = 0;
  String? _p1Resolved;
  String? _p2Resolved;
  final List _resolvedGames = [];

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyValid();
  }

  // Sometimes P1 is correct, but P2 is misspelled. This checks if we even need to ask about P1.
  void _checkIfAlreadyValid() {
    var c = widget.conflicts[_currentIndex];
    bool p1Valid = widget.allPlayers.any((p) => p.name == c['p1_target']);
    bool p2Valid = widget.allPlayers.any((p) => p.name == c['p2_target']);
    _p1Resolved = p1Valid ? c['p1_target'] : null;
    _p2Resolved = p2Valid ? c['p2_target'] : null;
  }

  void _nextConflict(bool skipGame) {
    if (!skipGame) {
      var c = widget.conflicts[_currentIndex];
      
      // Calculate the correct winner based on the user's new selections
      String winnerTarget = c['raw_winner'];
      String finalWinner = "Draw";
      double score = 0.5;

      if (winnerTarget == c['p1_target']) {
        finalWinner = _p1Resolved!;
        score = 1.0;
      } else if (winnerTarget == c['p2_target']) {
        finalWinner = _p2Resolved!;
        score = 0.0;
      }

      _resolvedGames.add({
        "player1": _p1Resolved,
        "player2": _p2Resolved,
        "winner": finalWinner,
        "score": score
      });
    }

    if (_currentIndex < widget.conflicts.length - 1) {
      setState(() {
        _currentIndex++;
        _checkIfAlreadyValid();
      });
    } else {
      Navigator.pop(context); // Close the dialog
      widget.onFinished(_resolvedGames); // Send the fixed games to the queue!
    }
  }

  Widget _buildSelectionUI(String target, List suggestions, String? currentValue, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Who is '$target'?", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        
        // Render ALL suggestions as clickable chips
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: suggestions.map((s) => ChoiceChip(
            label: Text(s),
            selectedColor: Colors.indigo.shade100,
            selected: currentValue == s,
            onSelected: (selected) {
              if (selected) onChanged(s.toString());
            },
          )).toList(),
        ),
        
        const SizedBox(height: 8),
        
        // Manual Override Dropdown
        DropdownButton<String>(
          isExpanded: true,
          hint: const Text("Or select manually from database..."),
          value: (currentValue != null && !suggestions.contains(currentValue)) ? currentValue : null,
          items: widget.allPlayers.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
          onChanged: onChanged,
        ),
        const Divider(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var c = widget.conflicts[_currentIndex];
    
    // Can only press "Next" if both players have been given valid names
    bool canProceed = _p1Resolved != null && _p2Resolved != null;

    return AlertDialog(
      title: Text("Conflict ${_currentIndex + 1} of ${widget.conflicts.length}"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text("Excel Row ${c['row']}: ${c['raw_match']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 20),
            
            if (_p1Resolved == null || !widget.allPlayers.any((p) => p.name == c['p1_target']))
              _buildSelectionUI(c['p1_target'], c['p1_suggestions'] ?? [], _p1Resolved, (v) => setState(() => _p1Resolved = v)),
              
            if (_p2Resolved == null || !widget.allPlayers.any((p) => p.name == c['p2_target']))
              _buildSelectionUI(c['p2_target'], c['p2_suggestions'] ?? [], _p2Resolved, (v) => setState(() => _p2Resolved = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _nextConflict(true),
          child: const Text("Skip This Game", style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: canProceed ? () => _nextConflict(false) : null,
          child: Text(_currentIndex == widget.conflicts.length - 1 ? "Finish" : "Next"),
        ),
      ],
    );
  }
}