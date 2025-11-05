import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../services/api_service.dart';

class EventForm extends StatefulWidget {
  final Event selectedEvent;

  const EventForm({super.key, required this.selectedEvent});

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ApiService _apiService = ApiService();
  int _selectedSeats = 1;
  bool _isRegistering = false;

  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSeats > widget.selectedEvent.remainingSeats) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough remaining seats available!')),
        );
        return;
      }
      
      setState(() { _isRegistering = true; });

      try {
        final RegistrationTicket ticket = await _apiService.registerEvent(
          widget.selectedEvent.id, 
          _nameController.text, 
          _emailController.text, 
          _selectedSeats,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Generating Ticket... 🎉')),
          );
          // Navigate to the new ticket page with the API response object
          Navigator.pushReplacementNamed(
            context,
            '/ticket',
            arguments: {'ticket': ticket},
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', 'Registration Failed: '))),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isRegistering = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Register for ${widget.selectedEvent.name}"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Event Info Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedEvent.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text("Date: ${widget.selectedEvent.date}", style: const TextStyle(fontSize: 15)),
                      Text("Location: ${widget.selectedEvent.location}", style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 6),
                      Text(
                        "Available Seats: ${widget.selectedEvent.remainingSeats}/${widget.selectedEvent.totalSeats}",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value!.isEmpty ? "Please enter your name" : null,
              ),
              const SizedBox(height: 15),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your email";
                  } else if (!value.contains("@")) {
                    return "Enter a valid email address";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 25),

              // Seat selection
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Select Seats:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.deepPurple,
                    ),
                    onPressed: () {
                      if (_selectedSeats > 1) {
                        setState(() {
                          _selectedSeats--;
                        });
                      }
                    },
                  ),
                  Text(
                    '$_selectedSeats',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.deepPurple,
                    ),
                    onPressed: () {
                      if (_selectedSeats < widget.selectedEvent.remainingSeats && _selectedSeats < 5) { // Enforce max 5 seats per request (matching FastAPI limit)
                        setState(() {
                          _selectedSeats++;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 35),

              // Submit button
              ElevatedButton(
                onPressed: _isRegistering ? null : _handleRegistration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                ),
                child: _isRegistering
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Generate Ticket",
                        style: TextStyle(color: Colors.white, fontSize: 17),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
