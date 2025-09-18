import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:juantap/pages/admin/admin.dart';
import 'package:juantap/pages/responders/responder.dart';
import 'package:juantap/pages/users/call_page.dart';
import 'package:juantap/pages/users/check_in.dart';
import 'package:juantap/pages/users/contact_lists.dart';
import 'package:juantap/pages/users/contact_lists_requests.dart';
import 'package:juantap/pages/users/edit_profile.dart';
import 'package:juantap/pages/users/home.dart';
import 'package:juantap/pages/users/login.dart';
import 'package:juantap/pages/users/maps_location.dart';
import 'package:juantap/pages/users/signup.dart';
import 'package:juantap/pages/users/splash_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';

// 👇 Add these for background service
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize background service
  await initializeService();

  final app = Firebase.app();
  debugPrint('Firebase project: ${app.options.projectId}');
  debugPrint('Database URL:     ${app.options.databaseURL}');
  debugPrint('Storage bucket:   ${app.options.storageBucket}');

  // Explicit Storage instance
  final storage = FirebaseStorage.instanceFor(bucket: 'juantap-db-2dbeb.appspot.com');
  debugPrint('Explicit bucket:  ${storage.bucket}');

  runApp(const JuanTap());
}

/// 🔧 Setup background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // starts only when user enables Voice Command
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(), // iOS has limited support
  );
}

/// 🚨 Runs when background service starts
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  // Keep the service alive
  if (service is AndroidServiceInstance) {
    service.on("setAsForeground").listen((event) {
      service.setAsForegroundService();
    });

    service.on("stopService").listen((event) {
      service.stopSelf();
    });
  }

  // Here later you can hook continuous speech recognition
  debugPrint("✅ Background Voice Service Started");
}

class JuanTap extends StatelessWidget {
  const JuanTap({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JuanTap',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthGate(),
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/registration': (context) => Registration(),
        '/edit_profile': (context) => EditProfilePage(),
        '/maps_location': (context) => MapsLocation(),
        '/check_in': (context) => CheckInPage(),
        '/contact_lists': (context) => ContactListPage(),
        '/contact_lists_requests': (context) => ContactListsRequestsPage(),
        '/admin': (context) => const admin(),
        '/responderDashboard': (context) => const ResponderDashboard(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _determineHomeScreen(User user) async {
    final roleSnapshot = await FirebaseDatabase.instance.ref('users/${user.uid}/role').get();
    final role = roleSnapshot.value;

    if (role == 'admin') {
      return const admin();
    } else if (role == 'responder') {
      return const ResponderDashboard();
    } else {
      return const HomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        } else if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: _determineHomeScreen(snapshot.data!),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              } else if (futureSnapshot.hasData) {
                return futureSnapshot.data!;
              } else {
                return const LoginPage();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
