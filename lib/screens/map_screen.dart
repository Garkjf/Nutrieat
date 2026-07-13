import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:convert';

class RestaurantMapPage extends StatefulWidget {
  const RestaurantMapPage({super.key});

  @override
  State<RestaurantMapPage> createState() => _RestaurantMapPageState();
}

class _RestaurantMapPageState extends State<RestaurantMapPage> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  
  double _currentRadius = 1500; // Default 1.5km
  String _selectedFilter = 'Healthy'; 
  final TextEditingController _searchController = TextEditingController();
  final String googleApiKey = "AIzaSyDoCtZEpgeBzgVAdELayldApJhW5wLpguM";

  // ADDED: 'Halal' to the filter list
  final List<String> _filters = ['Healthy', 'Halal', 'Vegan', 'Vegetarian', 'Keto', 'Salad'];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    _fetchNearbyRestaurants();
  }

  // FIXED: Directions logic to open actual Google Maps app
  Future<void> _launchMaps(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=walking");
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  Future<void> _fetchNearbyRestaurants() async {
    if (_currentPosition == null) return;
    
    final String query = "${_searchController.text} $_selectedFilter".trim();

    String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&radius=${_currentRadius.toInt()}' // Uses the dynamic radius from the slider
        '&type=restaurant'
        '&keyword=$query'
        '&key=$googleApiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];
      setState(() {
        _markers = results.map((place) => Marker(
          markerId: MarkerId(place['place_id']),
          position: LatLng(place['geometry']['location']['lat'], place['geometry']['location']['lng']),
          onTap: () => _fetchAndShowDetails(place['place_id']),
        )).toSet();
      });
    }
  }

  Future<void> _fetchAndShowDetails(String placeId) async {
    final url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,rating,opening_hours,vicinity,geometry&key=$googleApiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body)['result'];
      _showPlaceSheet(data);
    }
  }

  void _showPlaceSheet(Map<String, dynamic> place) {
    bool isOpen = place['opening_hours']?['open_now'] ?? false;
    final lat = place['geometry']['location']['lat'];
    final lng = place['geometry']['location']['lng'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(place['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: isOpen ? Colors.green : Colors.red)),
                    const SizedBox(width: 5),
                    Text(isOpen ? "Open Now" : "Closed", style: TextStyle(color: isOpen ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(place['vicinity'] ?? "No address"),
            const Divider(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _launchMaps(lat, lng),
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text("Get Directions", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 14),
                  onMapCreated: (c) => mapController = c,
                  markers: _markers,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),

          // TOP SECTION (Search + Filters)
          Positioned(
            top: 50, left: 0, right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(hintText: "Search restaurant...", border: InputBorder.none, icon: Icon(Icons.search)),
                    onSubmitted: (_) => _fetchNearbyRestaurants(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          selectedColor: const Color(0xFF2D6A4F),
                          labelStyle: TextStyle(color: _selectedFilter == filter ? Colors.white : Colors.black),
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                            _fetchNearbyRestaurants();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM SECTION: Distance Slider
          Positioned(
            bottom: 20, left: 15, right: 15,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Search Distance", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${(_currentRadius / 1000).toStringAsFixed(1)} km", style: const TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _currentRadius,
                      min: 500,  // 0.5 km
                      max: 5000, // 5.0 km
                      divisions: 9, 
                      activeColor: const Color(0xFF2D6A4F),
                      inactiveColor: Colors.green.shade100,
                      onChanged: (double value) {
                        setState(() {
                          _currentRadius = value;
                        });
                      },
                      onChangeEnd: (double value) {
                        _fetchNearbyRestaurants();
                      },
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