import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class DangerZonesPage extends StatefulWidget {
  const DangerZonesPage({super.key});

  @override
  State<DangerZonesPage> createState() => _DangerZonesPageState();
}

class _DangerZonesPageState extends State<DangerZonesPage> {
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref("danger_zones");

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  final TextEditingController _zoneNameController = TextEditingController();
  double _radius = 200;

  Map<String, dynamic> _dangerZones = {};

  @override
  void initState() {
    super.initState();
    _listenToDangerZones();
  }

  void _listenToDangerZones() {
    dbRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _dangerZones = data;
        });
      } else {
        setState(() {
          _dangerZones = {};
        });
      }
    });
  }

  void _addDangerZone() {
    if (_selectedLocation == null || _zoneNameController.text.isEmpty) return;

    final newZone = {
      "name": _zoneNameController.text.trim(),
      "lat": _selectedLocation!.latitude,
      "lng": _selectedLocation!.longitude,
      "radius": _radius,
      "reports": {} // ✅ store detailed reports
    };

    dbRef.push().set(newZone);

    setState(() {
      _selectedLocation = null;
      _zoneNameController.clear();
      _radius = 200;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("✅ Danger Zone Added")),
    );
  }

  void _cancelZoneSelection() {
    setState(() {
      _selectedLocation = null;
      _zoneNameController.clear();
      _radius = 200;
    });
  }

  // ✅ Add report message to Firebase
  void _addReport(String zoneId) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Incident"),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: "Enter incident details...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final message = messageController.text.trim();
              if (message.isNotEmpty) {
                dbRef.child(zoneId).child("reports").push().set({
                  "message": message,
                  "timestamp": DateTime.now().toIso8601String(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("📌 Report submitted")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  void _deleteZone(String zoneId, String zoneName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Danger Zone"),
        content: Text("Are you sure you want to delete \"$zoneName\"?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              dbRef.child(zoneId).remove();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("❌ Zone \"$zoneName\" removed")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // ✅ Show zone options + list of messages (reports)
  void _showZoneOptions(String zoneId, String zoneName, Map<String, dynamic> reports) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final reportList = reports.entries.toList();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(zoneName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // ✅ List of reports (messages)
              if (reportList.isEmpty)
                const Text("No reports yet",
                    style: TextStyle(color: Colors.grey))
              else
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: reportList.length,
                    itemBuilder: (context, index) {
                      final report =
                      Map<String, dynamic>.from(reportList[index].value);
                      return ListTile(
                        leading: const Icon(Icons.message, color: Colors.orange),
                        title: Text(report["message"] ?? "No message"),
                        subtitle: Text(report["timestamp"] ?? ""),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _addReport(zoneId);
                },
                icon: const Icon(Icons.report, color: Colors.white),
                label: const Text("Add Report"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteZone(zoneId, zoneName);
                },
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text("Delete Zone"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    Set<Circle> circles = {};

    _dangerZones.forEach((id, zoneData) {
      final zone = Map<String, dynamic>.from(zoneData);
      final LatLng position = LatLng(zone["lat"], zone["lng"]);
      final Map<String, dynamic> reports =
      (zone["reports"] is Map)
          ? Map<String, dynamic>.from(zone["reports"] as Map)
          : <String, dynamic>{};

      markers.add(
        Marker(
          markerId: MarkerId(id),
          position: position,
          infoWindow: InfoWindow(
            title: zone["name"],
            snippet: "Reports: ${reports.length}\n(Tap for details)",
            onTap: () => _showZoneOptions(id, zone["name"], reports),
          ),
        ),
      );

      circles.add(
        Circle(
          circleId: CircleId(id),
          center: position,
          radius: (zone["radius"] as num).toDouble(),
          fillColor: Colors.red.withOpacity(0.2),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Danger Zones"),
        backgroundColor: Colors.redAccent,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(10.3157, 123.8854),
              zoom: 13,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: markers,
            circles: circles,
            onTap: (latLng) {
              setState(() {
                _selectedLocation = latLng;
              });
            },
          ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _zoneNameController,
                        decoration: const InputDecoration(
                          labelText: "Zone Name",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.circle_outlined, size: 20),
                          const SizedBox(width: 6),
                          const Text("Radius: "),
                          Expanded(
                            child: Slider(
                              value: _radius,
                              min: 50,
                              max: 1000,
                              divisions: 19,
                              label: "${_radius.toInt()} m",
                              onChanged: (value) {
                                setState(() {
                                  _radius = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _cancelZoneSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text("Cancel"),
                          ),
                          ElevatedButton.icon(
                            onPressed: _addDangerZone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.add_location_alt),
                            label: const Text("Add Zone"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
