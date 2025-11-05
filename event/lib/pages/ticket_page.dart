import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../model/event_model.dart';
import '../services/api_service.dart';

class TicketPage extends StatelessWidget {
  final RegistrationTicket ticket;

  const TicketPage({
    super.key,
    required this.ticket,
  });
  
  // Note: We no longer have all seat information here. 
  // For simplicity, we assume the seats in the ticket object are the booked seats.
  // Full seat stats (total/remaining) should be fetched from the dashboard.
  
  // A small utility to extract simplified info from QR data (FastAPI sends raw string)
  Map<String, String> _extractEventDetails() {
    // Expected format: full_name|email|event_id|seats_booked|uuid
    final parts = ticket.qrData.split('|');
    if (parts.length >= 4) {
      // In a real app, you would fetch event details by event_id from the backend.
      // For this implementation, we use the eventName provided in the ticket response.
      return {
        'Registered Name': parts[0],
        'Email': parts[1],
        'Event ID': parts[2],
        'Seats Booked': parts[3],
      };
    }
    return {'Note': 'Could not parse all QR data'};
  }


  @override
  Widget build(BuildContext context) {
    final Map<String, String> details = _extractEventDetails();
    
    // Mock values for visualization - in a real app, this would be fetched
    // For this demo, we'll just show the name/email/seats
    const String mockEventDate = 'Date not included in Ticket API'; 
    const String mockEventLocation = 'Location not included in Ticket API'; 
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Event Ticket'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ticket.eventName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Showing mock date/location as the ticket API response was minimal
                  Text("Ticket ID: ${ticket.registrationId}", style: const TextStyle(fontSize: 16)),
                  Text("Date: $mockEventDate", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text("Location: $mockEventLocation", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 20),
                  
                  // QR Code based on the raw data from the API
                  QrImageView(
                    data: ticket.qrData,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.deepPurple),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.deepPurple),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text("Name: ${details['Registered Name']}", style: const TextStyle(fontSize: 16)),
                  Text("Email: ${details['Email']}", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  
                  Divider(thickness: 1.5, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  
                  _buildSeatInfo("Seats Booked", ticket.seats.toString(), Colors.deepPurple),

                  const SizedBox(height: 20),
                  
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/eventDashboard', (route) => false),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    label: const Text("Back to Events"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatInfo(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
