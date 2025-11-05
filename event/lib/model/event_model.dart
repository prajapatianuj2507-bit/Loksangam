import 'dart:convert';

enum EventStatus { pending, verified }

class Event {
  final int id; // Corresponds to MySQL 'id'
  final String name;
  final String date;
  final String location;
  final int totalSeats;
  final int remainingSeats;
  final EventStatus status;

  Event({
    required this.id,
    required this.name,
    required this.date,
    required this.location,
    required this.totalSeats,
    required this.remainingSeats,
    required this.status,
  });

  // Factory constructor to create an Event object from JSON (FastAPI response)
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int,
      name: json['name'] as String,
      date: json['event_date'] as String, // FastAPI uses 'event_date'
      location: json['location'] as String,
      totalSeats: json['total_seats'] as int,
      remainingSeats: json['remaining_seats'] as int,
      status: (json['status'] == 'verified')
          ? EventStatus.verified
          : EventStatus.pending,
    );
  }
}

class RegistrationTicket {
  final int registrationId;
  final String eventName;
  final String registeredName;
  final int seats;
  final String qrData;

  RegistrationTicket({
    required this.registrationId,
    required this.eventName,
    required this.registeredName,
    required this.seats,
    required this.qrData,
  });

  // Factory constructor for the ticket response from /event/register
  factory RegistrationTicket.fromJson(Map<String, dynamic> json) {
    return RegistrationTicket(
      registrationId: json['registration_id'] as int,
      eventName: json['event_name'] as String,
      registeredName: json['registered_name'] as String,
      seats: json['seats'] as int,
      qrData: json['qr_data'] as String,
    );
  }
}
