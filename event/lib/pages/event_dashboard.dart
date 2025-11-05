import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../services/api_service.dart';

class EventDashboard extends StatefulWidget {
  const EventDashboard({super.key});

  @override
  State<EventDashboard> createState() => _EventDashboardState();
}

class _EventDashboardState extends State<EventDashboard> {
  final ApiService _apiService = ApiService();
  late Future<List<Event>> _verifiedEventsFuture;
  late Future<List<Event>> _pendingEventsFuture;
  late String _userRole;

  @override
  void initState() {
    super.initState();
    _userRole = _apiService.getUserRole() ?? 'user';
    _fetchEvents();
  }

  void _fetchEvents() {
    setState(() {
      _verifiedEventsFuture = _apiService.getVerifiedEvents();
      if (_userRole == 'admin') {
        _pendingEventsFuture = _apiService.getPendingEvents();
      }
    });
  }

  Future<void> _handleVerifyEvent(int eventId, String eventName) async {
    try {
      await _apiService.verifyEvent(eventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verified event: $eventName')),
        );
        _fetchEvents(); // Refresh data after successful verification
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to verify: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    }
  }
  
  void _handleLogout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Widget _buildPendingEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Event Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        FutureBuilder<List<Event>>(
          future: _pendingEventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ));
            } else if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading pending requests: ${snapshot.error.toString().replaceFirst('Exception: ', '')}'),
              ));
            } else if (snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No pending requests.'),
              ));
            } else {
              return Column(
                children: snapshot.data!.map((event) => Card(
                  color: Colors.orange.shade50,
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${event.date} • ${event.location}'),
                    trailing: ElevatedButton(
                      onPressed: () => _handleVerifyEvent(event.id, event.name),
                      child: const Text('Verify'),
                    ),
                  ),
                )).toList(),
              );
            }
          },
        ),
        const Divider(thickness: 2, height: 40),
      ],
    );
  }

  Widget _buildVerifiedEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Available Events', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder<List<Event>>(
          future: _verifiedEventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ));
            } else if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading events: ${snapshot.error.toString().replaceFirst('Exception: ', '')}'),
              ));
            } else if (snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('No Events Available'));
            } else {
              return Column(
                children: snapshot.data!.map((event) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    title: Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${event.date} • ${event.location}\nSeats Left: ${event.remainingSeats}/${event.totalSeats}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/registerEvent',
                        arguments: {'selectedEvent': event}, // Pass the Event object
                      ).then((_) => _fetchEvents()); // Refresh data when returning from form
                    },
                  ),
                )).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events Dashboard"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchEvents,
            tooltip: 'Refresh Events',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _fetchEvents();
          // We wait for the futures to complete for the indicator to finish
          await Future.wait([_verifiedEventsFuture, if (_userRole == 'admin') _pendingEventsFuture]); 
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              if (_userRole == 'admin') _buildPendingEventsSection(),
              _buildVerifiedEventsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigating directly, the submission is handled by the API service
          Navigator.pushNamed(context, '/addEventRequest').then((_) => _fetchEvents()); 
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Request New Event',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
