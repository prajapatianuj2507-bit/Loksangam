import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model/event_model.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access the host machine (where FastAPI runs)
  // Use localhost for iOS Simulator or web
  static const String _baseUrl = 'http://127.0.0.1:8000';

  // Stored for future API calls
  static String? _accessToken;
  static String? _userRole;

  // --- Auth & Token Management ---

  Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
    _userRole = prefs.getString('userRole');
    return _accessToken != null;
  }

  String? getUserRole() => _userRole;

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('userRole');
    _accessToken = null;
    _userRole = null;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _userRole = data['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accessToken', _accessToken!);
      await prefs.setString('userRole', _userRole!);

      return {'success': true, 'message': data['message']};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Login failed');
    }
  }

  // --- Events: Fetching ---

  Future<List<Event>> getVerifiedEvents() async {
    final response = await http.get(Uri.parse('$_baseUrl/events'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Event.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load verified events');
    }
  }

  Future<List<Event>> getPendingEvents() async {
    // Only fetch if admin
    if (_userRole != 'admin') return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/pending_events'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      }, // Use token for Admin endpoint
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Event.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      // Forbidden, user is not admin
      return [];
    } else {
      throw Exception('Failed to load pending events');
    }
  }

  // --- Events: Management ---

  Future<void> verifyEvent(int eventId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/verify/$eventId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to verify event');
    }
  }

  Future<void> submitEventRequest(Event event) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/event/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode({
        'name': event.name,
        'event_date': event.date,
        'location': event.location,
        'total_seats': event.totalSeats,
      }),
    );

    if (response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Failed to submit event request');
    }
  }

  // --- Registration ---

  Future<RegistrationTicket> registerEvent(
    int eventId,
    String name,
    String email,
    int seats,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/event/register'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode({
        'event_id': eventId,
        'full_name': name,
        'email': email,
        'seats_booked': seats,
      }),
    );

    if (response.statusCode == 200) {
      return RegistrationTicket.fromJson(jsonDecode(response.body));
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Registration failed.');
    }
  }
}
