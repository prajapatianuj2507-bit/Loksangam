import 'package:flutter/material.dart';
import 'pages/splash.dart';
import 'pages/login.dart';
import 'pages/event_dashboard.dart';
import 'pages/event_form.dart';
import 'pages/add_event_request.dart';
import 'model/event_model.dart';
import 'pages/ticket_page.dart';

void main() {
  runApp(const LokSangamApp());
}

class LokSangamApp extends StatelessWidget {
  const LokSangamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LokSangam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ).copyWith(primary: Colors.deepPurple), // Set primary color for compatibility
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/eventDashboard':
            return MaterialPageRoute(builder: (_) => const EventDashboard());
          case '/registerEvent':
            final args = settings.arguments as Map<String, dynamic>?;
            // Now passes the full Event model
            if (args != null && args['selectedEvent'] is Event) { 
              return MaterialPageRoute(
                builder: (_) => EventForm(selectedEvent: args['selectedEvent']),
              );
            }
            return MaterialPageRoute(builder: (_) => const EventDashboard());
          case '/addEventRequest':
            // No need for onSubmit callback anymore, uses API service directly
            return MaterialPageRoute(builder: (_) => const AddEventRequest());
          case '/ticket':
             final args = settings.arguments as Map<String, dynamic>?;
             if (args != null && args['ticket'] is RegistrationTicket) {
                return MaterialPageRoute(
                  builder: (_) => TicketPage(ticket: args['ticket']),
                );
             }
            return MaterialPageRoute(builder: (_) => const EventDashboard());
          default:
            return null;
        }
      },
    );
  }
}
