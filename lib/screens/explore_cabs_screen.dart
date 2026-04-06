import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../providers/home_provider.dart';
import '../utils/app_theme.dart';
import '../utils/cities.dart';

class ExploreCabsScreen extends ConsumerStatefulWidget {
  final String pickupCity;
  final String dropCity;

  const ExploreCabsScreen({
    super.key,
    required this.pickupCity,
    required this.dropCity,
  });

  @override
  ConsumerState<ExploreCabsScreen> createState() => _ExploreCabsScreenState();
}

class _RouteFetchResult {
  final List<LatLng> points;
  final String? warning;

  const _RouteFetchResult({required this.points, this.warning});
}

class _GeocodeResult {
  final LatLng? latLng;
  final String? error;

  const _GeocodeResult({this.latLng, this.error});
}

class _ExploreCabsScreenState extends ConsumerState<ExploreCabsScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSub;

  // Map data
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentLatLng;
  LatLng? _startLatLng;
  LatLng? _pickupLatLng;
  LatLng? _dropLatLng;
  LatLng? _previousCabLatLng;
  LatLng? _renderCabLatLng;
  List<LatLng> _plannedRoutePoints = [];
  double _cabBearing = 0;
  int _cabAnimationVersion = 0;
  bool _isRouteLoading = false;
  bool _isCorrectingPickupToCurrent = false;
  int _pickupCorrectionAttempts = 0;
  String? _routeLoadMessage;
  String? _lastGeocodeError;
  String? _lastRouteApiError;

  // Hive box for coordinates
  late Box _coordBox;

  // Default center (Bengaluru)
  static const LatLng _defaultCenter = LatLng(12.9716, 77.5946);
  static const String _directionsApiKey = String.fromEnvironment(
    'GOOGLE_DIRECTIONS_API_KEY',
    defaultValue: '',
  );
  static const Map<String, String> _cityAliases = {
    'banglore': 'Bangalore',
    'bengaluru': 'Bangalore',
    'calcutta': 'Kolkata',
    'bombay': 'Mumbai',
    'delhi ncr': 'New Delhi',
  };

  @override
  void initState() {
    super.initState();
    _initHive();
    _checkLocationPermission();
    _startLocationStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rideProvider.notifier).init(widget.pickupCity, widget.dropCity);
      _prepareExpectedRoute();
    });
  }

  Future<void> _initHive() async {
    _coordBox = await Hive.openBox('ride_coordinates');
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _onLivePosition(position);
      if (ref.read(rideProvider).status != RideStatus.active) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLatLng!, 14),
        );
      }
    } catch (_) {
      // keep default center if location isn't available
    }
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(_onLivePosition);
  }

  void _onLivePosition(Position position) {
    if (!mounted) return;

    final rawLatLng = LatLng(position.latitude, position.longitude);
    final snappedLatLng = _snapToPlannedRoute(rawLatLng);
    final cabLatLng = snappedLatLng ?? rawLatLng;

    // Read once before mutating provider state.
    final isActive = ref.read(rideProvider).status == RideStatus.active;

    if (isActive) {
      final routeBearing = snappedLatLng == null
          ? null
          : _routeBearingAt(snappedLatLng);
      if (routeBearing != null) {
        _cabBearing = routeBearing;
      }

      if (_previousCabLatLng != null) {
        final travelMeters = Geolocator.distanceBetween(
          _previousCabLatLng!.latitude,
          _previousCabLatLng!.longitude,
          cabLatLng.latitude,
          cabLatLng.longitude,
        );
        if (travelMeters >= 2 && routeBearing == null) {
          _cabBearing = Geolocator.bearingBetween(
            _previousCabLatLng!.latitude,
            _previousCabLatLng!.longitude,
            cabLatLng.latitude,
            cabLatLng.longitude,
          );
        }
      }

      _saveCoord(cabLatLng);
      ref
          .read(rideProvider.notifier)
          .addCoordinate(cabLatLng.latitude, cabLatLng.longitude);

      if (_startLatLng != null) {
        final distKm = _calculateDistance(_startLatLng!, cabLatLng);
        ref.read(rideProvider.notifier).updateDistance(distKm);
      }
    }

    final coords = ref.read(rideProvider).coordinates;

    setState(() {
      _currentLatLng = cabLatLng;

      _setLiveMarkerPosition(
        isActive: isActive,
        position: isActive ? (_renderCabLatLng ?? cabLatLng) : cabLatLng,
      );

      // Keep expected route and update only tracked route line.
      if (isActive && coords.length >= 2) {
        _polylines.removeWhere((p) => p.polylineId.value == 'tracked_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('tracked_route'),
            points: coords.map((c) => LatLng(c['lat']!, c['lng']!)).toList(),
            color: Colors.blueAccent,
            width: 5,
          ),
        );
      }
    });

    if (isActive) {
      _animateCabMarkerTo(cabLatLng);
    } else {
      _maybeCorrectPlannedPickupToCurrent();
      _cabAnimationVersion++;
      _renderCabLatLng = null;
    }

    _previousCabLatLng = cabLatLng;
  }

  Future<void> _maybeCorrectPlannedPickupToCurrent() async {
    if (_pickupCorrectionAttempts >= 3 || _isCorrectingPickupToCurrent) return;
    if (_isRouteLoading) return;
    if (_dropLatLng == null ||
        _currentLatLng == null ||
        _pickupLatLng == null) {
      return;
    }

    final rideStatus = ref.read(rideProvider).status;
    if (rideStatus == RideStatus.active) return;

    final driftMeters = Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      _pickupLatLng!.latitude,
      _pickupLatLng!.longitude,
    );

    // If pickup marker is already near user, no correction is needed.
    if (driftMeters < 1500) {
      _pickupCorrectionAttempts = 3;
      return;
    }

    _pickupCorrectionAttempts += 1;
    _isCorrectingPickupToCurrent = true;
    try {
      final shouldUseCurrent = await _shouldUseCurrentLocationAsPickup();
      if (!shouldUseCurrent || _currentLatLng == null || _dropLatLng == null) {
        return;
      }

      final livePickup = _currentLatLng!;
      final routeResult = await _fetchDrivingRoutePoints(
        livePickup,
        _dropLatLng!,
      );
      if (!mounted) return;

      setState(() {
        _pickupLatLng = livePickup;
        _plannedRoutePoints = routeResult.points;

        _markers.removeWhere((m) => m.markerId.value == 'pickup');
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: livePickup,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Pickup: ${widget.pickupCity}',
              snippet: 'Using your current location',
            ),
            zIndex: 3,
          ),
        );

        _polylines.removeWhere((p) => p.polylineId.value == 'planned_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: _plannedRoutePoints,
            color: AppColors.primary,
            width: 6,
            geodesic: false,
          ),
        );

        _routeLoadMessage =
            routeResult.warning ?? 'Pickup adjusted to your current location.';
      });

      _fitRouteInView(_plannedRoutePoints);
      _pickupCorrectionAttempts = 3;
    } finally {
      _isCorrectingPickupToCurrent = false;
    }
  }

  void _setLiveMarkerPosition({
    required bool isActive,
    required LatLng position,
  }) {
    _markers.removeWhere(
      (m) => m.markerId.value == 'current' || m.markerId.value == 'cab',
    );

    _markers.add(
      Marker(
        markerId: MarkerId(isActive ? 'cab' : 'current'),
        position: position,
        icon: isActive
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
            : BitmapDescriptor.defaultMarkerWithHue(AppColors.mapMarkerHue),
        infoWindow: InfoWindow(
          title: isActive ? 'Cab (Live)' : 'Your Current Location',
          snippet: isActive
              ? '${widget.pickupCity} → ${widget.dropCity}'
              : widget.pickupCity,
        ),
        rotation: isActive ? _cabBearing : 0,
        flat: isActive,
        anchor: const Offset(0.5, 1.0),
        zIndex: isActive ? 5 : 2,
      ),
    );
  }

  Future<void> _animateCabMarkerTo(LatLng target) async {
    final start = _renderCabLatLng ?? _previousCabLatLng ?? target;
    final distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      target.latitude,
      target.longitude,
    );

    // Tiny movement does not need an animation.
    if (distance < 3) {
      if (!mounted) return;
      setState(() {
        _renderCabLatLng = target;
        _setLiveMarkerPosition(isActive: true, position: target);
      });
      _mapController?.moveCamera(CameraUpdate.newLatLng(target));
      return;
    }

    final int run = ++_cabAnimationVersion;
    const int totalMs = 700;
    const int stepMs = 35;
    final int steps = (totalMs / stepMs).round();

    for (int i = 1; i <= steps; i++) {
      if (!mounted || run != _cabAnimationVersion) return;

      final t = Curves.easeOut.transform(i / steps);
      final lat = start.latitude + (target.latitude - start.latitude) * t;
      final lng = start.longitude + (target.longitude - start.longitude) * t;
      final interpolated = LatLng(lat, lng);

      setState(() {
        _renderCabLatLng = interpolated;
        _setLiveMarkerPosition(isActive: true, position: interpolated);
      });

      if (i.isEven) {
        _mapController?.moveCamera(CameraUpdate.newLatLng(interpolated));
      }

      await Future<void>.delayed(const Duration(milliseconds: stepMs));
    }

    if (!mounted || run != _cabAnimationVersion) return;
    setState(() {
      _renderCabLatLng = target;
      _setLiveMarkerPosition(isActive: true, position: target);
    });
    _mapController?.moveCamera(CameraUpdate.newLatLng(target));
  }

  Future<void> _prepareExpectedRoute() async {
    setState(() {
      _isRouteLoading = true;
      _routeLoadMessage = null;
    });

    try {
      final pickup = await _resolvePickupLatLng();
      final drop = await _resolveDropLatLng();

      if (pickup == null || drop == null) {
        if (!mounted) return;
        setState(() {
          _isRouteLoading = false;
          _routeLoadMessage = _lastGeocodeError == null
              ? 'Could not find one of the city names. Try full names like Bangalore, Kolkata.'
              : 'City lookup failed: ${_lastGeocodeError!}';
        });
        return;
      }

      final routeResult = await _fetchDrivingRoutePoints(pickup, drop);
      final routePoints = routeResult.points;
      if (!mounted) return;

      setState(() {
        _pickupLatLng = pickup;
        _dropLatLng = drop;
        _plannedRoutePoints = routePoints;

        _markers.removeWhere(
          (m) => m.markerId.value == 'pickup' || m.markerId.value == 'dropoff',
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Pickup: ${widget.pickupCity}',
              snippet: 'Starting point',
            ),
            zIndex: 3,
          ),
        );
        _markers.add(
          Marker(
            markerId: const MarkerId('dropoff'),
            position: drop,
            infoWindow: InfoWindow(
              title: 'Drop: ${widget.dropCity}',
              snippet: 'Destination',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            zIndex: 3,
          ),
        );

        _polylines.removeWhere((p) => p.polylineId.value == 'planned_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: routePoints,
            color: AppColors.primary,
            width: 6,
            geodesic: false,
          ),
        );

        _isRouteLoading = false;
        _routeLoadMessage = routeResult.warning;
      });

      _fitRouteInView(routePoints);
      _mapController?.showMarkerInfoWindow(const MarkerId('pickup'));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRouteLoading = false;
        _routeLoadMessage = 'Could not load route right now.';
      });
    }
  }

  Future<LatLng?> _resolvePickupLatLng() async {
    if (widget.pickupCity.trim().isEmpty) {
      return _getBestCurrentLatLng();
    }

    if (await _shouldUseCurrentLocationAsPickup()) {
      return _getBestCurrentLatLng();
    }

    return _resolveCityLatLng(widget.pickupCity);
  }

  Future<LatLng?> _getBestCurrentLatLng() async {
    if (_currentLatLng != null) return _currentLatLng;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final live = LatLng(position.latitude, position.longitude);
      if (!mounted) return live;
      setState(() => _currentLatLng = live);
      return live;
    } catch (_) {
      return _currentLatLng;
    }
  }

  Future<bool> _shouldUseCurrentLocationAsPickup() async {
    final current = await _getBestCurrentLatLng();
    if (current == null || widget.pickupCity.trim().isEmpty) return false;

    try {
      final placemarks = await placemarkFromCoordinates(
        current.latitude,
        current.longitude,
      );
      if (placemarks.isEmpty) return false;

      final placemark = placemarks.first;
      final detectedCity = placemark.locality?.trim().isNotEmpty == true
          ? placemark.locality!.trim()
          : (placemark.subAdministrativeArea?.trim().isNotEmpty == true
                ? placemark.subAdministrativeArea!.trim()
                : (placemark.administrativeArea?.trim().isNotEmpty == true
                      ? placemark.administrativeArea!.trim()
                      : null));

      if (detectedCity == null || detectedCity.isEmpty) return false;
      if (_isSameCityName(widget.pickupCity, detectedCity)) {
        return true;
      }
    } catch (_) {
      // Continue to distance-based fallback below.
    }

    // Fallback: if user city center is close to current GPS, treat it as same-city pickup.
    final typedCityCenter = await _resolveCityLatLng(widget.pickupCity);
    if (typedCityCenter == null) return false;

    final distanceToTypedCityCenter = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      typedCityCenter.latitude,
      typedCityCenter.longitude,
    );

    return distanceToTypedCityCenter <= 45000;
  }

  bool _isSameCityName(String a, String b) {
    String normalize(String value) {
      final compact = value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final alias = _cityAliases[compact];
      return (alias ?? compact).toLowerCase();
    }

    final left = normalize(a);
    final right = normalize(b);

    if (left == right) return true;
    if (left.contains(right) || right.contains(left)) return true;
    return false;
  }

  Future<LatLng?> _resolveDropLatLng() async {
    if (widget.dropCity.trim().isEmpty) return null;

    return _resolveCityLatLng(widget.dropCity);
  }

  Future<LatLng?> _resolveCityLatLng(String rawCity) async {
    final cleaned = rawCity.trim();
    if (cleaned.isEmpty) return null;

    final normalizedKey = cleaned.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final canonicalFromAlias = _cityAliases[normalizedKey];
    final canonicalFromList = _findCanonicalIndianCity(cleaned);
    final canonical = canonicalFromAlias ?? canonicalFromList ?? cleaned;

    final queries = <String>{
      canonical,
      '$canonical, India',
      cleaned,
      '$cleaned, India',
    };

    _lastGeocodeError = null;

    // Prefer Google Geocoding API for consistent results across devices.
    for (final query in queries) {
      final result = await _resolveWithGoogleGeocoding(query);
      if (result.latLng != null) {
        return result.latLng;
      }
      _lastGeocodeError = result.error ?? _lastGeocodeError;
    }

    // Fallback to platform geocoder.
    for (final query in queries) {
      try {
        final points = await locationFromAddress(query);
        if (points.isNotEmpty) {
          return LatLng(points.first.latitude, points.first.longitude);
        }
      } catch (_) {
        // Try next query variant
      }
    }

    return null;
  }

  Future<_GeocodeResult> _resolveWithGoogleGeocoding(String query) async {
    if (_directionsApiKey.isEmpty) {
      return const _GeocodeResult(error: 'Missing API key for Geocoding API.');
    }

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': query,
        'components': 'country:IN',
        'key': _directionsApiKey,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return _GeocodeResult(
          error: 'Geocoding API HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'UNKNOWN';
      if (status != 'OK') {
        final apiMessage = data['error_message'] as String?;
        final suffix = apiMessage == null ? '' : ' ($apiMessage)';
        return _GeocodeResult(error: 'Geocoding status: $status$suffix');
      }

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return const _GeocodeResult(error: 'Geocoding returned no results.');
      }

      final first = results.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        return const _GeocodeResult(error: 'Geocoding coordinates missing.');
      }

      return _GeocodeResult(latLng: LatLng(lat, lng));
    } catch (e) {
      return _GeocodeResult(error: 'Geocoding request failed: $e');
    }
  }

  String? _findCanonicalIndianCity(String city) {
    final normalized = city.toLowerCase().trim();
    for (final known in indianCities) {
      if (known.toLowerCase() == normalized) {
        return known;
      }
    }
    return null;
  }

  Future<_RouteFetchResult> _fetchDrivingRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    _lastRouteApiError = null;

    if (_directionsApiKey.isEmpty) {
      return _RouteFetchResult(
        points: [origin, destination],
        warning: 'Directions API key is missing. Showing basic route line.',
      );
    }

    final directionsPoints = await _fetchFromDirectionsApi(origin, destination);
    if (directionsPoints != null && directionsPoints.length >= 2) {
      return _RouteFetchResult(points: directionsPoints);
    }

    final routesApiPoints = await _fetchFromRoutesApi(origin, destination);
    if (routesApiPoints != null && routesApiPoints.length >= 2) {
      return _RouteFetchResult(points: routesApiPoints);
    }

    return _RouteFetchResult(
      points: [origin, destination],
      warning: _lastRouteApiError == null
          ? 'Road route could not be fetched from Google APIs. Showing basic path.'
          : 'Route API failed: ${_lastRouteApiError!}',
    );
  }

  Future<List<LatLng>?> _fetchFromDirectionsApi(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '${origin.latitude},${origin.longitude}',
            'destination': '${destination.latitude},${destination.longitude}',
            'mode': 'driving',
            'key': _directionsApiKey,
          });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _lastRouteApiError = 'Directions HTTP ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? 'UNKNOWN';
      if (status != 'OK') {
        final msg = data['error_message'] as String?;
        _lastRouteApiError = msg == null
            ? 'Directions status: $status'
            : 'Directions status: $status ($msg)';
        return null;
      }
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final detailed = <LatLng>[];
      final legs = route['legs'] as List<dynamic>?;
      if (legs != null) {
        for (final leg in legs) {
          final legMap = leg as Map<String, dynamic>?;
          final steps = legMap?['steps'] as List<dynamic>?;
          if (steps == null) continue;

          for (final step in steps) {
            final stepMap = step as Map<String, dynamic>?;
            final stepPolyline = stepMap?['polyline'] as Map<String, dynamic>?;
            final stepEncoded = stepPolyline?['points'] as String?;
            if (stepEncoded == null || stepEncoded.isEmpty) continue;

            final decodedStep = _decodePolyline(stepEncoded);
            _appendPolylinePoints(detailed, decodedStep);
          }
        }
      }

      if (detailed.length >= 2) {
        return detailed;
      }

      final overview = route['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = _decodePolyline(encoded);
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      _lastRouteApiError = 'Directions request failed.';
      return null;
    }
  }

  Future<List<LatLng>?> _fetchFromRoutesApi(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final uri = Uri.parse(
        'https://routes.googleapis.com/directions/v2:computeRoutes',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _directionsApiKey,
              'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {
                    'latitude': origin.latitude,
                    'longitude': origin.longitude,
                  },
                },
              },
              'destination': {
                'location': {
                  'latLng': {
                    'latitude': destination.latitude,
                    'longitude': destination.longitude,
                  },
                },
              },
              'travelMode': 'DRIVE',
              'routingPreference': 'TRAFFIC_AWARE',
              'polylineQuality': 'OVERVIEW',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _lastRouteApiError = 'Routes API HTTP ${response.statusCode}';
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('error')) {
        final err = data['error'] as Map<String, dynamic>?;
        final message = err?['message'] as String?;
        _lastRouteApiError = message == null
            ? 'Routes API error.'
            : 'Routes API error: $message';
        return null;
      }
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final first = routes.first as Map<String, dynamic>;
      final polyline = first['polyline'] as Map<String, dynamic>?;
      final encoded = polyline?['encodedPolyline'] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = _decodePolyline(encoded);
      return decoded.isEmpty ? null : decoded;
    } catch (_) {
      _lastRouteApiError = 'Routes API request failed.';
      return null;
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final polyline = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }

  void _appendPolylinePoints(List<LatLng> target, List<LatLng> segment) {
    if (segment.isEmpty) return;
    if (target.isEmpty) {
      target.addAll(segment);
      return;
    }

    final last = target.last;
    final first = segment.first;
    final sameStart =
        (last.latitude - first.latitude).abs() < 1e-6 &&
        (last.longitude - first.longitude).abs() < 1e-6;
    if (sameStart) {
      target.addAll(segment.skip(1));
    } else {
      target.addAll(segment);
    }
  }

  Future<void> _fitRouteInView(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  Future<void> _startRide() async {
    final useCurrentAsPickup = await _shouldUseCurrentLocationAsPickup();
    final liveStart = useCurrentAsPickup ? await _getBestCurrentLatLng() : null;

    if (useCurrentAsPickup && liveStart != null && _dropLatLng != null) {
      final routeResult = await _fetchDrivingRoutePoints(
        liveStart,
        _dropLatLng!,
      );
      if (!mounted) return;
      setState(() {
        _pickupLatLng = liveStart;
        _plannedRoutePoints = routeResult.points;
        _polylines.removeWhere((p) => p.polylineId.value == 'planned_route');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('planned_route'),
            points: _plannedRoutePoints,
            color: AppColors.primary,
            width: 6,
            geodesic: false,
          ),
        );

        _markers.removeWhere((m) => m.markerId.value == 'pickup');
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: liveStart,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: 'Pickup: ${widget.pickupCity}',
              snippet: 'Starting from your live location',
            ),
            zIndex: 3,
          ),
        );
      });
    }

    ref.read(rideProvider.notifier).startRide();
    final routeStart = (useCurrentAsPickup && liveStart != null)
        ? liveStart
        : _plannedRoutePoints.isNotEmpty
        ? _plannedRoutePoints.first
        : (_pickupLatLng ?? _currentLatLng ?? _defaultCenter);

    if (_plannedRoutePoints.length >= 2) {
      final from = _plannedRoutePoints.first;
      final to = _plannedRoutePoints[1];
      _cabBearing = Geolocator.bearingBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
    } else {
      _cabBearing = 0;
    }

    _startLatLng = routeStart;
    _previousCabLatLng = routeStart;
    _renderCabLatLng = routeStart;
    _cabAnimationVersion++;

    // Save start coord to Hive
    _coordBox.clear();
    _saveCoord(routeStart);

    if (_currentLatLng != null ||
        _pickupLatLng != null ||
        _plannedRoutePoints.isNotEmpty) {
      ref
          .read(rideProvider.notifier)
          .addCoordinate(routeStart.latitude, routeStart.longitude);

      // Show cab marker instantly on start ride without waiting for next stream tick.
      setState(() {
        _currentLatLng = routeStart;
        _setLiveMarkerPosition(isActive: true, position: routeStart);
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(routeStart, 16));
      _mapController?.showMarkerInfoWindow(const MarkerId('cab'));
    }
  }

  LatLng? _snapToPlannedRoute(LatLng point) {
    if (_plannedRoutePoints.length < 2) return null;

    final px = point.longitude;
    final py = point.latitude;

    LatLng? bestPoint;
    double bestDist2 = double.infinity;

    for (int i = 0; i < _plannedRoutePoints.length - 1; i++) {
      final a = _plannedRoutePoints[i];
      final b = _plannedRoutePoints[i + 1];

      final ax = a.longitude;
      final ay = a.latitude;
      final bx = b.longitude;
      final by = b.latitude;

      final abx = bx - ax;
      final aby = by - ay;
      final apx = px - ax;
      final apy = py - ay;
      final abLen2 = abx * abx + aby * aby;
      if (abLen2 == 0) continue;

      double t = (apx * abx + apy * aby) / abLen2;
      t = t.clamp(0.0, 1.0);

      final qx = ax + (abx * t);
      final qy = ay + (aby * t);
      final dx = px - qx;
      final dy = py - qy;
      final dist2 = dx * dx + dy * dy;

      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        bestPoint = LatLng(qy, qx);
      }
    }

    if (bestPoint == null) return null;

    final snapDistance = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      bestPoint.latitude,
      bestPoint.longitude,
    );

    // Avoid hard-snapping when user is far from planned corridor.
    if (snapDistance > 120) {
      return null;
    }
    return bestPoint;
  }

  double? _routeBearingAt(LatLng point) {
    if (_plannedRoutePoints.length < 2) return null;

    final px = point.longitude;
    final py = point.latitude;

    int bestIndex = -1;
    double bestDist2 = double.infinity;

    for (int i = 0; i < _plannedRoutePoints.length - 1; i++) {
      final a = _plannedRoutePoints[i];
      final b = _plannedRoutePoints[i + 1];

      final ax = a.longitude;
      final ay = a.latitude;
      final bx = b.longitude;
      final by = b.latitude;

      final abx = bx - ax;
      final aby = by - ay;
      final apx = px - ax;
      final apy = py - ay;
      final abLen2 = abx * abx + aby * aby;
      if (abLen2 == 0) continue;

      double t = (apx * abx + apy * aby) / abLen2;
      t = t.clamp(0.0, 1.0);

      final qx = ax + (abx * t);
      final qy = ay + (aby * t);
      final dx = px - qx;
      final dy = py - qy;
      final dist2 = dx * dx + dy * dy;

      if (dist2 < bestDist2) {
        bestDist2 = dist2;
        bestIndex = i;
      }
    }

    if (bestIndex < 0) return null;
    final from = _plannedRoutePoints[bestIndex];
    final to = _plannedRoutePoints[bestIndex + 1];
    final bearing = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    return bearing;
  }

  Future<void> _openTurnByTurnNavigation() async {
    final destination = _dropLatLng;
    if (destination == null) return;
    final origin = _pickupLatLng ?? _currentLatLng;

    final lat = destination.latitude;
    final lng = destination.longitude;
    final originParam = origin != null
        ? '&origin=${origin.latitude},${origin.longitude}'
        : '';

    final androidNav = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final iosGoogleMaps = Uri.parse(
      'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
    );
    final appleMaps = Uri.parse(
      'http://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
    );
    final webMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng$originParam&travelmode=driving',
    );

    if (Platform.isAndroid && await canLaunchUrl(androidNav)) {
      await launchUrl(androidNav, mode: LaunchMode.externalApplication);
      return;
    }

    if (Platform.isIOS && await canLaunchUrl(iosGoogleMaps)) {
      await launchUrl(iosGoogleMaps, mode: LaunchMode.externalApplication);
      return;
    }

    if (Platform.isIOS && await canLaunchUrl(appleMaps)) {
      await launchUrl(appleMaps, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(webMaps)) {
      await launchUrl(webMaps, mode: LaunchMode.externalApplication);
    }
  }

  void _saveCoord(LatLng latLng) {
    _coordBox.add({'lat': latLng.latitude, 'lng': latLng.longitude});
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km
    final dLat = _deg2rad(to.latitude - from.latitude);
    final dLon = _deg2rad(to.longitude - from.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(from.latitude)) *
            cos(_deg2rad(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _plannedRouteDistanceKm() {
    if (_plannedRoutePoints.length < 2) return 0;
    double totalKm = 0;
    for (int i = 0; i < _plannedRoutePoints.length - 1; i++) {
      totalKm += _calculateDistance(
        _plannedRoutePoints[i],
        _plannedRoutePoints[i + 1],
      );
    }
    return totalKm;
  }

  String _estimatedTripTimeLabel() {
    double routeKm = _plannedRouteDistanceKm();
    if (routeKm <= 0 && _pickupLatLng != null && _dropLatLng != null) {
      routeKm = _calculateDistance(_pickupLatLng!, _dropLatLng!);
    }
    if (routeKm <= 0) return '--';

    // Approximate city + highway mixed speed for ETA display.
    const avgSpeedKmPerHour = 38.0;
    final minutes = max(1, ((routeKm / avgSpeedKmPerHour) * 60).round());
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 ? '${hours}h ${mins}m' : '${mins} min';
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  Future<void> _endRide() async {
    ref.read(rideProvider.notifier).endRide();
    _startLatLng = null;
    _previousCabLatLng = null;
    _renderCabLatLng = null;
    _cabAnimationVersion++;
    _cabBearing = 0;
    await _showRideSummary();

    if (!mounted) return;
    ref.read(rideProvider.notifier).reset();
    setState(() {
      _polylines.removeWhere((p) => p.polylineId.value == 'tracked_route');
      _markers.removeWhere((m) => m.markerId.value == 'cab');
    });
    Navigator.pop(context);
  }

  Future<void> _showRideSummary() {
    final rideState = ref.read(rideProvider);
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.primary, size: 56),
            const SizedBox(height: 12),
            Text(
              'Ride Completed!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${rideState.distanceCovered.toStringAsFixed(2)} km covered',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Back to Home',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideProvider);
    final etaLabel = _estimatedTripTimeLabel();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? _defaultCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLatLng != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLatLng!, 14),
                );
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.pickupCity.isEmpty
                                      ? 'Pickup Location'
                                      : widget.pickupCity,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 1,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.flag,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.dropCity.isEmpty
                                      ? 'Drop Location'
                                      : widget.dropCity,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            rideState.status == RideStatus.active
                                ? Icons.local_taxi
                                : Icons.route,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rideState.status == RideStatus.active
                                ? 'Ride in Progress'
                                : 'Trip Controls',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: const Color(0xFF1F2729),
                            ),
                          ),
                          if (rideState.status == RideStatus.active) ...[
                            const SizedBox(width: 10),
                            Text(
                              'ETA: $etaLabel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Odometer
                  _OdometerWidget(km: rideState.distanceCovered),

                  const SizedBox(height: 14),

                  // Start / End ride button
                  Row(
                    children: [
                      Expanded(
                        child: _RideButton(
                          label: rideState.status == RideStatus.active
                              ? 'End Ride'
                              : 'Start Ride',
                          color: rideState.status == RideStatus.active
                              ? Colors.red
                              : AppColors.primary,
                          icon: rideState.status == RideStatus.active
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          onTap: rideState.status == RideStatus.active
                              ? _endRide
                              : () {
                                  _startRide();
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RideButton(
                          label: 'Open on Maps',
                          color: const Color(0xFF1F2729),
                          icon: Icons.navigation_rounded,
                          onTap: _openTurnByTurnNavigation,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (rideState.status == RideStatus.active)
                    Text(
                      'GPS updating continuously on active route',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  if (_isRouteLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Loading expected route...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  if (_routeLoadMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _routeLoadMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red.shade400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: 280,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── Odometer Widget ──────────────────────────────
class _OdometerWidget extends StatelessWidget {
  final double km;

  const _OdometerWidget({required this.km});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.speed, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance Covered',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              Text(
                '${km.toStringAsFixed(2)} km',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── Ride Button ──────────────────────────────
class _RideButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _RideButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
