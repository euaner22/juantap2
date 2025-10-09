import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class GeofencingPage extends StatefulWidget {
  const GeofencingPage({super.key});

  @override
  State<GeofencingPage> createState() => _GeofencingPageState();
}

class _GeofencingPageState extends State<GeofencingPage>
    with SingleTickerProviderStateMixin {
  late final DatabaseReference _zonesRef;
  final MapController _mapCtrl = MapController();

  final List<Map<String, dynamic>> _zones = [];
  final _labelCtrl = TextEditingController();
  double _radius = 150;

  String? _focusedZoneId;
  LatLng? _focusedPosition;
  double _pulseRadius = 0;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _zonesRef = FirebaseDatabase.instance.ref('danger_zones');
    _loadZones();
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  // 🔁 Load zones
  void _loadZones() {
    _zonesRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;
      final Map<dynamic, dynamic> zones =
      Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, dynamic>> loadedZones = [];

      zones.forEach((id, data) {
        final z = Map<String, dynamic>.from(data);
        loadedZones.add({
          'id': id,
          'name': z['name'] ?? z['label'] ?? 'Unnamed Zone',
          'lat': (z['lat'] as num?)?.toDouble() ?? 0,
          'lng': (z['lng'] as num?)?.toDouble() ?? 0,
          'radius': (z['radius'] as num?)?.toDouble() ?? 100,
        });
      });

      setState(() {
        _zones
          ..clear()
          ..addAll(loadedZones);
      });
    });
  }

  // 💾 Save new zone
  Future<void> _saveZone(LatLng center, String label, double radius) async {
    final id = _zonesRef.push().key!;
    await _zonesRef.child(id).set({
      'name': label.isEmpty ? 'Danger Zone' : label,
      'lat': center.latitude,
      'lng': center.longitude,
      'radius': radius,
      'reports': {'reports_count': 0},
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Danger zone added successfully')),
    );
  }

  // 🗑️ Delete zone
  Future<void> _deleteZone(String id) async {
    await _zonesRef.child(id).remove();
    setState(() => _zones.removeWhere((z) => z['id'] == id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Zone deleted successfully')),
    );
  }

  // 📍 Add zone modal
  void _openAddZoneDialog(LatLng latLng) {
    double tempRadius = _radius;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF9FFF9), Color(0xFFE8FFF3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent,
                blurRadius: 10,
                offset: Offset(1, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "New Danger Zone",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF084C41),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _labelCtrl,
                    decoration: InputDecoration(
                      prefixIcon:
                      const Icon(Icons.label_outline, color: Colors.black54),
                      labelText: "Zone Label (e.g. High Crime Area)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.redAccent),
                        onPressed: () => setModalState(() =>
                        tempRadius = (tempRadius - 10).clamp(50, 1000)),
                      ),
                      Expanded(
                        child: Slider(
                          min: 50,
                          max: 1000,
                          divisions: 95,
                          value: tempRadius,
                          activeColor: Colors.teal,
                          onChanged: (v) => setModalState(() => tempRadius = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        onPressed: () => setModalState(() =>
                        tempRadius = (tempRadius + 10).clamp(50, 1000)),
                      ),
                      Text("${tempRadius.toStringAsFixed(0)} m"),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF1E88E5), // ✅ same blue as close button
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 14),
                      shadowColor: const Color(0xFF1E88E5).withOpacity(0.4),
                    ),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      "Save Zone",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _radius = tempRadius);
                      _saveZone(latLng, _labelCtrl.text.trim(), tempRadius);
                      _labelCtrl.clear();
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 🗺️ Tap to add
  void _onTap(LatLng latLng) => _openAddZoneDialog(latLng);

  // 🎯 Focus zone
  void _focusOnZone(Map<String, dynamic> zone) {
    final LatLng target = LatLng(zone['lat'], zone['lng']);
    final double radius = zone['radius'];
    _mapCtrl.move(target, 17);
    setState(() {
      _focusedZoneId = zone['id'];
      _focusedPosition = target;
      _pulseRadius = 0;
    });

    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      setState(() {
        _pulseRadius += 8;
        if (_pulseRadius >= radius) _pulseRadius = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(10.3236, 123.9221);

    final List<Marker> markers = _zones.map((z) {
      final bool isFocused = z['id'] == _focusedZoneId;
      return Marker(
        width: isFocused ? 50 : 40,
        height: isFocused ? 50 : 40,
        point: LatLng(z['lat'], z['lng']),
        child: Icon(
          Icons.warning_amber_rounded,
          color: isFocused ? Colors.orangeAccent : Colors.deepOrange,
          size: isFocused ? 48 : 36,
        ),
      );
    }).toList();

    final List<CircleMarker> circles = [
      ..._zones.map((z) => CircleMarker(
        point: LatLng(z['lat'], z['lng']),
        color: Colors.orange.withOpacity(0.25),
        borderStrokeWidth: 2,
        borderColor: Colors.deepOrange,
        useRadiusInMeter: true,
        radius: z['radius'],
      )),
      if (_focusedPosition != null && _focusedZoneId != null)
        CircleMarker(
          point: _focusedPosition!,
          color: Colors.orangeAccent.withOpacity(0.2),
          borderStrokeWidth: 1.5,
          borderColor: Colors.orangeAccent,
          useRadiusInMeter: true,
          radius: _pulseRadius,
        ),
    ];

    return Container(
      // ✅ Gradient background (same as IncidentReportsPage)
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFC8F4E4),
            Color(0xFFA7E2C9),
            Color(0xFF7FD1AE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 🗺️ Map panel with same surface tone
            Expanded(
              flex: 3,
              child: Card(
                color: const Color(0xFFFAFCFF), // ✅ Same surface as reports
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: defaultCenter,
                    initialZoom: 15,
                    onTap: (_, latlng) => _onTap(latlng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.juantap.admin',
                    ),
                    CircleLayer(circles: circles),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildRightPanel()),
          ],
        ),
      ),
    );
  }

  // 📋 Right panel
  Widget _buildRightPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFF), // ✅ Same as card surface
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Geofencing Zones",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF084C41),
            ),
          ),
          const Divider(height: 24),

          // 🆕 Enlarged instruction box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FFF9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.deepOrange, size: 30),
                    SizedBox(width: 10),
                    Text(
                      "How to Use Geofencing Map",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF084C41),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  "🗺️ Tap anywhere on the map to add a new Danger Zone.\n"
                      "💡 Tap an existing zone below to focus and highlight it on the map.\n"
                      " Use the delete icon to remove a zone from the list.",
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.location_pin, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text(
                "Total Zones: ${_zones.length}",
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _zones.length,
              itemBuilder: (context, index) {
                final zone = _zones[index];
                final bool isFocused = _focusedZoneId == zone['id'];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFocused
                          ? [Color(0xFFFFE0B2), Color(0xFFFFCC80)]
                          : [Color(0xFFFFF3E0), Color(0xFFFFEFD5)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.25),
                        blurRadius: 8,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepOrange,
                      child: Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                    ),
                    title: Text(
                      zone['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF084C41),
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      "Lat: ${zone['lat'].toStringAsFixed(4)}, Lng: ${zone['lng'].toStringAsFixed(4)}",
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFF1E88E5)), // blue delete icon
                      onPressed: () => _deleteZone(zone['id'].toString()),
                    ),
                    onTap: () => _focusOnZone(zone),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
