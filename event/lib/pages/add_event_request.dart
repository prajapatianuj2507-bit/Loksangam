import 'package:flutter/material.dart';
import '../model/event_model.dart';
import '../services/api_service.dart';

class AddEventRequest extends StatefulWidget {
  // Removed final void Function(Event) onSubmit;
  const AddEventRequest({super.key});

  @override
  State<AddEventRequest> createState() => _AddEventRequestState();
}

class _AddEventRequestState extends State<AddEventRequest> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _seatsController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      
      try {
        // Construct a partial Event object for data consistency
        final tempEvent = Event(
          id: 0, // Placeholder ID
          name: _nameController.text,
          date: _dateController.text,
          location: _locationController.text,
          totalSeats: int.parse(_seatsController.text),
          remainingSeats: 0,
          status: EventStatus.pending,
        );

        await _apiService.submitEventRequest(tempEvent);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event request submitted for verification!')),
          );
        }
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Submission Failed: ${e.toString().replaceFirst('Exception: ', '')}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Request New Event"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Event Name', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter event name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Date (e.g., 25 Oct 2025)', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter date' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Please enter location' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _seatsController,
                decoration: const InputDecoration(labelText: 'Total Seats', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter seats';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Submit Event Request", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
