
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'LoginPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "xyz",
      appId: "1:400440232703:android:6c2b2958f199413c17daca",
      messagingSenderId: "400440232703",
      projectId: "pet-track-288ac",
      databaseURL: "https://pet-track-288ac-default-rtdb.asia-southeast1.firebasedatabase.app/",
    ),
  );
  runApp(const PetTrackerApp());
}

class PetTrackerApp extends StatelessWidget {
  const PetTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.hasData ? const HomePage() : const LoginPage();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng _petLocation = const LatLng(18.46443, 73.8357);
  final MapController _mapController = MapController();
  bool _isMapExpanded = false;
  double _mapHeight = 200.0;
  double _currentZoom = 14.0;
  LatLng? _geofenceCenter;
  double _geofenceRadius = 100.0; // in meters

  // Database reference
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Pet health data
  int _heartRate = 0;
  double _temperature = 0.0;
  int _steps = 0;
  String _activityStatus = 'Unknown';

  @override
  void initState() {
    super.initState();
    _initializeDatabaseListeners();
  }

  void _initializeDatabaseListeners() {
    _databaseRef.child('pets/dog1/location').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final newLocation = LatLng(
          data['latitude'] ?? 18.46443,
          data['longitude'] ?? 73.8357,
        );

        setState(() {
          _petLocation = newLocation;
        });

        _mapController.move(_petLocation, _currentZoom);

        // Check geofence violation
        _checkGeofenceViolation(newLocation);
      }
    });

    _databaseRef.child('pets/dog1/health').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _heartRate = data['heart_rate'] ?? 0;
          _temperature = (data['temperature'] ?? 0.0).toDouble();
          _steps = data['steps'] ?? 0;
          _activityStatus = _getActivityStatus(_steps);
        });
      }
    });
  }

  void _checkGeofenceViolation(LatLng currentLocation) {
    if (_geofenceCenter != null) {
      final distance = Distance();
      final meters = distance(_geofenceCenter!, currentLocation);

      if (meters > _geofenceRadius) {
        _showNotification('Geofence Alert', 'Your pet has left the safe zone!');
      }
    }
  }

  void _showNotification(String title, String message) {
    // In a real app, you would use flutter_local_notifications package
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: Colors.red,
        )
    );
  }

  String _getActivityStatus(int steps) {
    if (steps > 8000) return 'Very Active';
    if (steps > 5000) return 'Active';
    if (steps > 2000) return 'Moderate';
    return 'Inactive';
  }

  Future<void> _callVet() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '9881621676');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone app'))
      );
    }
  }

  void _setupGeofence() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Up Geofence'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Long press on map to set center'),
            Slider(
              value: _geofenceRadius,
              min: 50,
              max: 1000,
              divisions: 19,
              label: '${_geofenceRadius.round()} meters',
              onChanged: (value) {
                setState(() {
                  _geofenceRadius = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _geofenceCenter = _petLocation;
              });
              Navigator.pop(context);
              _showNotification('Geofence Set', 'Safe zone established');
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'App Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('Dark Mode'),
              value: false,
              onChanged: (value) {},
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: _buildCustomAppBar(context),
            shape: const ContinuousRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
              child: _buildHealthStatusCard(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildQuickActions(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location Tracking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isMapExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.blue,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMapExpanded = !_isMapExpanded;
                            _mapHeight = _isMapExpanded
                                ? MediaQuery.of(context).size.height * 0.6
                                : 200.0;
                          });
                        },
                      ),
                    ],
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _mapHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildMap(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updatePetData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _petLocation,
            initialZoom: _currentZoom,
            onMapReady: () {
              _currentZoom = _mapController.camera.zoom;
            },
            onLongPress: (tapPosition, latLng) {
              if (_geofenceCenter == null) {
                setState(() {
                  _geofenceCenter = latLng;
                });
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.example.pet_tracker',
            ),
            if (_geofenceCenter != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _geofenceCenter!,
                    color: Colors.blue.withOpacity(0.3),
                    borderColor: Colors.blue,
                    borderStrokeWidth: 2,
                    radius: _geofenceRadius,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _petLocation,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.pets,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                if (_geofenceCenter != null)
                  Marker(
                    point: _geofenceCenter!,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (_geofenceCenter != null)
          Positioned(
            bottom: 10,
            right: 10,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  _geofenceCenter = null;
                });
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: Icons.call,
                label: 'Call Vet',
                color: const Color(0xFF22C55E),
                bgColor: const Color(0xFFF0FDF4),
                onTap: _callVet,
              ),
              _buildActionButton(
                icon: FontAwesomeIcons.mapMarkedAlt,
                label: 'Geofence',
                color: const Color(0xFFA855F7),
                bgColor: const Color(0xFFFAF5FF),
                onTap: _setupGeofence,
              ),
              _buildActionButton(
                icon: Icons.settings,
                label: 'Settings',
                color: const Color(0xFFF97316),
                bgColor: const Color(0xFFFFF7ED),
                onTap: _openSettings,
              ),
              _buildActionButton(
                icon: Icons.location_on,
                label: 'Track',
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
                onTap: () {
                  _mapController.move(_petLocation, _currentZoom);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _updatePetData() {
    final random = Random();
    final updates = {
      'pets/dog1/location': {
        'latitude': _petLocation.latitude + 0.001 * (random.nextDouble() - 0.5),
        'longitude': _petLocation.longitude + 0.001 * (random.nextDouble() - 0.5),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      'pets/dog1/health': {
        'heart_rate': 70 + random.nextInt(30),
        'temperature': 30.0 + (random.nextDouble() * 2 - 1),
        'steps': _steps + random.nextInt(100),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };

    _databaseRef.update(updates);
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF0DED53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: const DecorationImage(
                    image: AssetImage('assets/images/Golden-Retriever.webp'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(width: 15),
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Labrador, 2 years',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Health Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthCard(
                context,
                icon: FontAwesomeIcons.heartPulse,
                title: 'Heart Rate',
                value: '$_heartRate BPM',
                color: const Color(0xFF22C55E),
                bgColor: const Color(0xFFF0FDF4),
              ),
              _buildHealthCard(
                context,
                icon: FontAwesomeIcons.temperatureLow,
                title: 'Temperature',
                value: '${_temperature.toStringAsFixed(1)}°C',
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHealthCard(
                context,
                icon: FontAwesomeIcons.running,
                title: 'Activity',
                value: _activityStatus,
                color: const Color(0xFFA855F7),
                bgColor: const Color(0xFFFAF5FF),
              ),
              _buildHealthCard(
                context,
                icon: FontAwesomeIcons.dog,
                title: 'Steps',
                value: '$_steps',
                color: const Color(0xFFEAB308),
                bgColor: const Color(0xFFFEFCE8),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: (MediaQuery
          .of(context)
          .size
          .width - 72) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
