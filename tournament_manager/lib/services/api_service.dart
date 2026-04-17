import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/player.dart';
import 'dart:io';

class ApiService {
  // --- CONFIGURATION ---
  // For Android Emulator use: "http://10.0.2.2:8000"
  // For Physical Phone over Wi-Fi use your local IPv4 address (e.g., "http://192.168.1.X:8000")
  // For Remote Tailscale access use your Tailscale IP (e.g., "http://100.X.X.X:8000")

  static const String baseUrl = "http://100.116.62.123:8001";
  //static const String baseUrl = 'http://10.0.2.2:8000';
  
  static Future<List<Player>> fetchPlayers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/players'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => Player.fromJson(item)).toList();
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Failed. Is Python running?");
    }
  }

  static Future<String?> addGame(String p1, String p2, double result) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "player1_name": p1,
          "player2_name": p2,
          "result": result
        }),
      );
      
      if (response.statusCode != 200) {
        return jsonDecode(response.body)['detail'] ?? "Unknown Error";
      }
      return null; 
    } catch (e) {
      return "Connection Error";
    }
  }

  static Future<List<dynamic>> processTournament() async {
    final response = await http.post(Uri.parse('$baseUrl/tournament/process'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      throw Exception(data['message']);
    } else {
      throw Exception("Server Error");
    }
  }

  static Future<String?> createPlayer(String name, double rating, double rd, double vol) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/players'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "rating": rating,
          "rd": rd,
          "vol": vol
        }),
      );
      if (response.statusCode != 200) {
        return "Error: ${response.body}";
      }
      return null; 
    } catch (e) {
      return "Connection Error";
    }
  }

  static Future<List<dynamic>> fetchTiers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tiers'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Failed to load tiers");
    } catch (e) {
      throw Exception("Connection Error");
    }
  }

  static Future<String?> updateTier(String tier, double rating, double rd, double vol) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tiers/update'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "group_tier": tier,
          "rating": rating,
          "rd": rd,
          "vol": vol
        }),
      );
      if (response.statusCode != 200) return "Error: ${response.body}";
      return null;
    } catch (e) {
      return "Connection Error";
    }
  }

  static Future<String?> resetTier(String tier) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tiers/reset'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"group_tier": tier}),
      );
      if (response.statusCode != 200) return "Error: ${response.body}";
      return null;
    } catch (e) {
      return "Connection Error";
    }
  }

  static Future<String?> undoLastTournament() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/tournament/undo'));
      if (response.statusCode == 200) {
        return null; 
      } else {
        final errorBody = jsonDecode(response.body);
        return errorBody['detail'] ?? "Unknown Error Occurred";
      }
    } catch (e) {
      return "Connection Error";
    }
  }

  static Future<Map<String, dynamic>> uploadTournamentExcel(String filePath) async {
    try {
      var uri = Uri.parse('$baseUrl/upload_tournament_excel/');
      var request = http.MultipartRequest('POST', uri);
      
      // Attach the excel file to the request
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // If the backend throws a 400 error (e.g., bad file format)
        var errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to upload file');
      }
    } catch (e) {
      throw Exception('Error uploading Excel file: $e');
    }
  }

  // --- DELETE PLAYER ---
  static Future<String?> deletePlayer(String playerName) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/players/$playerName'));
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ?? 'Failed to delete player';
    } catch (e) {
      return e.toString();
    }
  }

  // --- EDIT PLAYER ---
  static Future<String?> updatePlayer(String oldName, Map<String, dynamic> updateData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/players/$oldName'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(updateData),
      );
      if (response.statusCode == 200) return null; // Success
      return jsonDecode(response.body)['detail'] ?? 'Failed to update player';
    } catch (e) {
      return e.toString();
    }
  }
}