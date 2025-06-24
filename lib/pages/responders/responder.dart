// Add this import
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'send_alert_response.dart';
import 'incident_reports.dart';
import 'package:juantap/pages/users/login.dart';

class ResponderDashboard extends StatelessWidget {
  const ResponderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Notifications',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Responder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _profileImage;
  final _nameController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  String _username = '';
  bool _isMounted = true;
  List<Map<String, String>> recentAlerts = [];

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    _listenToResponderAlerts();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  void _listenToResponderAlerts() {
    final responderAlertsRef = FirebaseDatabase.instance.ref('responder_alerts');

    responderAlertsRef.onChildAdded.listen((event) {
      final locationSnapshot = event.snapshot.child('location');
      if (locationSnapshot.value == null || !_isMounted) return;

      final locationData = Map<String, dynamic>.from(locationSnapshot.value as Map);
      final username = locationData['username'];
      final lat = locationData['lat'];
      final lng = locationData['lng'];

      final alert = {
        'name': username.toString(),
        'location': '$lat, $lng',
        'time': TimeOfDay.now().format(context),
        'reason': 'SOS Alert',
        'date': DateTime.now().toLocal().toString().split(' ')[0],
        'image': 'https://via.placeholder.com/60',
      };

      setState(() {
        recentAlerts.add(alert);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted || !context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: const Color(0xFFFFEAEA),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🚨 SOS Alert', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('from $username', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    Text('Location: $lat, $lng'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SendAlertResponsePage(data: alert)),
                            );
                          },
                          child: const Text('Accept', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      });
    });
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _updateName() async {
    if (user != null) {
      final newName = _nameController.text.trim();
      if (newName.isNotEmpty) {
        await FirebaseDatabase.instance.ref("users/${user!.uid}/username").set(newName);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated successfully')));
        setState(() => _username = newName);
        Navigator.pop(context);
      }
    }
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _updateName, child: const Text('Save')),
        ],
      ),
    );
  }

  void _fetchUsername() async {
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance.ref("users/${user!.uid}/username").get();
      if (snapshot.exists) {
        setState(() => _username = snapshot.value.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = recentAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFF2A9D8F),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A9D8F),
        elevation: 0,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage != null
                    ? FileImage(_profileImage!)
                    : const AssetImage('assets/shield.png') as ImageProvider,
              ),
            ),
            const SizedBox(height: 10),
            Text(_username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton(onPressed: _showEditNameDialog, child: const Text("Edit Name")),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _logout, child: const Text("Logout")),
          ],
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Emergency Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (notifications.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: Text('Recent Alerts:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final latLngParts = item['location']!.split(',');
                      final lat = double.tryParse(latLngParts[0].trim()) ?? 0;
                      final lng = double.tryParse(latLngParts[1].trim()) ?? 0;

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SendAlertResponsePage(data: item)),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAEA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(item['image']!),
                                    radius: 25,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14)),
                                        Text(item['location']!, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 160,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 14),
                                  markers: {
                                    Marker(
                                      markerId: MarkerId(item['name']!),
                                      position: LatLng(lat, lng),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  liteModeEnabled: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const IncidentReportsPage()));
              },
              child: const Icon(Icons.description_outlined, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}