import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ──────────────── Trip type enum ────────────────
enum TripType { outstation, local, airport }

// ──────────────── Direction enum for airport transfers ────────────────
enum AirportDirection { toAirport, fromAirport }

// ──────────────── Trip mode enum ────────────────
enum TripMode { oneWay, roundTrip }

// ──────────────── Home screen state model ────────────────
class HomeState {
  final TripType tripType;
  final TripMode tripMode;
  final AirportDirection airportDirection;
  final String pickupCity;
  final String dropCity;
  final DateTime? pickupDate;
  final DateTime? toDate;
  final TimeOfDay? time;

  const HomeState({
    this.tripType = TripType.outstation,
    this.tripMode = TripMode.oneWay,
    this.airportDirection = AirportDirection.toAirport,
    this.pickupCity = '',
    this.dropCity = '',
    this.pickupDate,
    this.toDate,
    this.time,
  });

  HomeState copyWith({
    TripType? tripType,
    TripMode? tripMode,
    AirportDirection? airportDirection,
    String? pickupCity,
    String? dropCity,
    DateTime? pickupDate,
    DateTime? toDate,
    TimeOfDay? time,
    bool clearPickupDate = false,
    bool clearToDate = false,
    bool clearTime = false,
  }) {
    return HomeState(
      tripType: tripType ?? this.tripType,
      tripMode: tripMode ?? this.tripMode,
      airportDirection: airportDirection ?? this.airportDirection,
      pickupCity: pickupCity ?? this.pickupCity,
      dropCity: dropCity ?? this.dropCity,
      pickupDate: clearPickupDate ? null : (pickupDate ?? this.pickupDate),
      toDate: clearToDate ? null : (toDate ?? this.toDate),
      time: clearTime ? null : (time ?? this.time),
    );
  }
}

// ──────────────── Home Notifier ────────────────
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState());

  void setTripType(TripType type) => state = state.copyWith(tripType: type);
  void setTripMode(TripMode mode) => state = state.copyWith(tripMode: mode);
  void setAirportDirection(AirportDirection dir) =>
      state = state.copyWith(airportDirection: dir);
  void setPickupCity(String city) => state = state.copyWith(pickupCity: city);
  void setDropCity(String city) => state = state.copyWith(dropCity: city);
  void clearPickupCity() => state = state.copyWith(pickupCity: '');
  void clearDropCity() => state = state.copyWith(dropCity: '');
  void setPickupDate(DateTime date) => state = state.copyWith(pickupDate: date);
  void setToDate(DateTime date) => state = state.copyWith(toDate: date);
  void setTime(TimeOfDay time) => state = state.copyWith(time: time);
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) => HomeNotifier(),
);

// ──────────────── Navigation provider ────────────────
final navIndexProvider = StateProvider<int>((ref) => 0);

// ──────────────── Ride state for explore cabs screen ────────────────
enum RideStatus { idle, active, ended }

class RideState {
  final RideStatus status;
  final double distanceCovered; // in km
  final List<Map<String, double>> coordinates;
  final String pickupCity;
  final String dropCity;

  const RideState({
    this.status = RideStatus.idle,
    this.distanceCovered = 0.0,
    this.coordinates = const [],
    this.pickupCity = '',
    this.dropCity = '',
  });

  RideState copyWith({
    RideStatus? status,
    double? distanceCovered,
    List<Map<String, double>>? coordinates,
    String? pickupCity,
    String? dropCity,
  }) {
    return RideState(
      status: status ?? this.status,
      distanceCovered: distanceCovered ?? this.distanceCovered,
      coordinates: coordinates ?? this.coordinates,
      pickupCity: pickupCity ?? this.pickupCity,
      dropCity: dropCity ?? this.dropCity,
    );
  }
}

class RideNotifier extends StateNotifier<RideState> {
  RideNotifier() : super(const RideState());

  void init(String pickup, String drop) {
    state = RideState(
      status: RideStatus.idle,
      distanceCovered: 0.0,
      coordinates: const [],
      pickupCity: pickup,
      dropCity: drop,
    );
  }

  void startRide() {
    state = state.copyWith(
      status: RideStatus.active,
      distanceCovered: 0.0,
      coordinates: const [],
    );
  }

  void endRide() {
    state = state.copyWith(status: RideStatus.ended);
  }

  void updateDistance(double km) {
    state = state.copyWith(distanceCovered: km);
  }

  void addCoordinate(double lat, double lng) {
    final newCoords = [
      ...state.coordinates,
      {'lat': lat, 'lng': lng},
    ];
    state = state.copyWith(coordinates: newCoords);
  }

  void reset() {
    state = const RideState();
  }
}

final rideProvider = StateNotifierProvider<RideNotifier, RideState>(
  (ref) => RideNotifier(),
);
