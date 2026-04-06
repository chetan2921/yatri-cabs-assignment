import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/home_provider.dart';
import '../utils/app_theme.dart';
import '../utils/cities.dart';
import '../widgets/city_search_field.dart';
import '../widgets/date_time_field.dart';
import '../widgets/yatri_logo.dart';
import '../widgets/promo_banner.dart';
import 'explore_cabs_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  static const Color _exploreButtonColor = Color(0xFF38B000);

  bool _isValidLocation(String value) => value.trim().length >= 2;

  String? _getExploreValidationError(HomeState state) {
    if (!_isValidLocation(state.pickupCity)) {
      return 'Please enter a valid pickup location.';
    }

    final needsDropLocation = state.tripType == TripType.outstation;
    if (needsDropLocation && !_isValidLocation(state.dropCity)) {
      return 'Please enter a valid drop location.';
    }

    if (needsDropLocation &&
        state.pickupCity.trim().toLowerCase() ==
            state.dropCity.trim().toLowerCase()) {
      return 'Pickup and drop locations cannot be the same.';
    }

    if (state.pickupDate == null) {
      return 'Please select a valid pickup date.';
    }

    if (state.tripType == TripType.outstation &&
        state.tripMode == TripMode.roundTrip) {
      if (state.toDate == null) {
        return 'Please select a valid return date.';
      }
      if (state.toDate!.isBefore(state.pickupDate!)) {
        return 'Return date cannot be before pickup date.';
      }
    }

    if (state.time == null) {
      return 'Please select a valid pickup time.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.02),

                      // Header Row: Logo + Notification
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const YatriCabsLogo(height: 64),
                          _NotificationIcon(),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Tagline
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "India's Leading ",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: 'Inter-City\n',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: 'One Way ',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: AppColors.primary,
                              ),
                            ),
                            TextSpan(
                              text: 'Cab Service Provider',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Promo Banner
                      const PromoBanner(),

                      SizedBox(height: screenHeight * 0.02),

                      // Trip Type Tabs
                      _TripTypeTabs(
                        selected: state.tripType,
                        onSelect: notifier.setTripType,
                      ),

                      // Keep trip mode separate from the form section
                      if (state.tripType == TripType.outstation) ...[
                        SizedBox(height: screenHeight * 0.02),
                        _TripModeToggle(
                          mode: state.tripMode,
                          onSelect: notifier.setTripMode,
                        ),
                      ],

                      SizedBox(height: screenHeight * 0.02),

                      // White Card with form
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Airport direction toggle
                            if (state.tripType == TripType.airport)
                              _AirportDirectionToggle(
                                direction: state.airportDirection,
                                onSelect: notifier.setAirportDirection,
                              ),

                            if (state.tripType == TripType.airport)
                              const SizedBox(height: 16),

                            // Form fields based on trip type
                            if (state.tripType == TripType.outstation)
                              _OutstationForm(state: state, notifier: notifier),

                            if (state.tripType == TripType.local)
                              _LocalForm(state: state, notifier: notifier),

                            if (state.tripType == TripType.airport)
                              _AirportForm(state: state, notifier: notifier),

                            const SizedBox(height: 20),

                            // Explore Cabs Button
                            Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 232,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final error = _getExploreValidationError(
                                      state,
                                    );
                                    if (error != null) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(error),
                                            backgroundColor: const Color(
                                              0xFFD32F2F,
                                            ),
                                          ),
                                        );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExploreCabsScreen(
                                          pickupCity: state.pickupCity,
                                          dropCity: state.dropCity,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _exploreButtonColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Explore Cabs',
                                    style: AppTextStyles.exploreCabs,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Bottom illustration banner
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F8EE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: _BottomIllustration()),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Nav Bar
            const _BottomNavBar(),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────── Notification Icon ──────────────────────────────
class _NotificationIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 42,
          height: 42,
          // decoration: BoxDecoration(
          //   shape: BoxShape.circle,
          //   border: Border.all(color: Colors.white30),
          // ),
          child: const Icon(
            Icons.notifications_active,
            color: Colors.white,
            size: 24,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────── Trip Type Tabs ──────────────────────────────
class _TripTypeTabs extends StatelessWidget {
  final TripType selected;
  final ValueChanged<TripType> onSelect;

  const _TripTypeTabs({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Row(
        children: [
          Expanded(
            child: _TripTab(
              assetPath:
                  'assets/images/8495ed5b80b326fb9213a56470cf7cce50138b4f.png',
              label: 'Outstation Trip',
              selected: selected == TripType.outstation,
              onTap: () => onSelect(TripType.outstation),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TripTab(
              assetPath:
                  'assets/images/0a9d82c7427caa4cc984e08a45a84bfbd994a195.png',
              label: 'Local Trip',
              selected: selected == TripType.local,
              onTap: () => onSelect(TripType.local),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TripTab(
              assetPath:
                  'assets/images/db4f9199f9fbbdd40cca0c337a70d7bdced87f47.png',
              label: 'Airport Transfer',
              selected: selected == TripType.airport,
              onTap: () => onSelect(TripType.airport),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTab extends StatelessWidget {
  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TripTab({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              assetPath,
              width: 36,
              height: 36,
              color: selected ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: selected
                  ? AppTextStyles.tabLabelActive
                  : AppTextStyles.tabLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────── Trip Mode Toggle ──────────────────────────────
class _TripModeToggle extends StatelessWidget {
  final TripMode mode;
  final ValueChanged<TripMode> onSelect;

  const _TripModeToggle({required this.mode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => onSelect(TripMode.oneWay),
            child: SizedBox(
              width: 140,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: mode == TripMode.oneWay
                      ? AppColors.primary
                      : Colors.white,
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'One-way',
                    style: mode == TripMode.oneWay
                        ? AppTextStyles.toggleActive
                        : AppTextStyles.toggleInactive,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: () => onSelect(TripMode.roundTrip),
            child: SizedBox(
              width: 140,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: mode == TripMode.roundTrip
                      ? AppColors.primary
                      : Colors.white,
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Round Trip',
                    style: mode == TripMode.roundTrip
                        ? AppTextStyles.toggleActive
                        : AppTextStyles.toggleInactive,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── Airport Direction Toggle ──────────────────────────────
class _AirportDirectionToggle extends StatelessWidget {
  final AirportDirection direction;
  final ValueChanged<AirportDirection> onSelect;

  const _AirportDirectionToggle({
    required this.direction,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onSelect(AirportDirection.toAirport),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: direction == AirportDirection.toAirport
                    ? AppColors.primary
                    : Colors.white,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'To The Airport',
                  style: direction == AirportDirection.toAirport
                      ? AppTextStyles.toggleActive.copyWith(fontSize: 13)
                      : AppTextStyles.toggleInactive.copyWith(fontSize: 13),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onSelect(AirportDirection.fromAirport),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: direction == AirportDirection.fromAirport
                    ? AppColors.primary
                    : Colors.white,
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'From The Airport',
                  style: direction == AirportDirection.fromAirport
                      ? AppTextStyles.toggleActive.copyWith(fontSize: 13)
                      : AppTextStyles.toggleInactive.copyWith(fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────── Outstation Form ──────────────────────────────
class _OutstationForm extends ConsumerWidget {
  final HomeState state;
  final HomeNotifier notifier;

  const _OutstationForm({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Pickup City
        CitySearchField(
          label: 'Pick-up City',
          hint: 'Type City Name',
          value: state.pickupCity,
          leadingIcon: Image.asset(
            'assets/images/f31d259897b60d1e77dba5c9332f76ff8fa62152.png',
            width: 28,
            height: 28,
          ),
          trailingIcon: const Icon(
            Icons.close,
            weight: 3,
            size: 16,
            color: Colors.black54,
          ),
          onChanged: notifier.setPickupCity,
          onClear: notifier.clearPickupCity,
        ),
        const SizedBox(height: 20),

        // Drop City / Destination
        CitySearchField(
          label: state.tripMode == TripMode.oneWay
              ? 'Drop City'
              : 'Destination',
          hint: 'Type City Name',
          value: state.dropCity,
          leadingIcon: Image.asset(
            'assets/images/Group (6).png',
            width: 26,
            height: 26,
          ),
          trailingIcon: state.tripMode == TripMode.oneWay
              ? const Icon(Icons.close, size: 16, color: Colors.black54)
              : const Icon(Icons.add, size: 16, color: Colors.black54),
          onChanged: notifier.setDropCity,
          onClear: notifier.clearDropCity,
        ),
        const SizedBox(height: 20),

        // Date fields
        if (state.tripMode == TripMode.oneWay)
          DateTimeField(
            label: 'Pick-up Date',
            value: state.pickupDate != null
                ? DateFormat('dd-MM-yyyy').format(state.pickupDate!)
                : 'DD-MM-YYYY',
            leadingIcon: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.fieldBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/Group (2).png',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) =>
                    Theme(data: _datePickerTheme(ctx), child: child!),
              );
              if (picked != null) notifier.setPickupDate(picked);
            },
          )
        else
          DualDateField(
            fromDate: state.pickupDate != null
                ? DateFormat('dd-MM-yyyy').format(state.pickupDate!)
                : 'DD-MM-YYYY',
            toDate: state.toDate != null
                ? DateFormat('dd-MM-yyyy').format(state.toDate!)
                : 'DD-MM-YYYY',
            onFromDateTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) =>
                    Theme(data: _datePickerTheme(ctx), child: child!),
              );
              if (picked != null) notifier.setPickupDate(picked);
            },
            onToDateTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.pickupDate ?? DateTime.now(),
                firstDate: state.pickupDate ?? DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) =>
                    Theme(data: _datePickerTheme(ctx), child: child!),
              );
              if (picked != null) notifier.setToDate(picked);
            },
          ),

        const SizedBox(height: 20),

        // Time
        DateTimeField(
          label: 'Time',
          value: state.time != null ? state.time!.format(context) : 'HH:MM',
          leadingIcon: Image.asset(
            'assets/images/Group (1).png',
            width: 28,
            height: 28,
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (ctx, child) =>
                  Theme(data: _datePickerTheme(ctx), child: child!),
            );
            if (picked != null) notifier.setTime(picked);
          },
        ),
      ],
    );
  }
}

// ────────────────────────────── Local Form ──────────────────────────────
class _LocalForm extends ConsumerWidget {
  final HomeState state;
  final HomeNotifier notifier;

  const _LocalForm({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        CitySearchField(
          label: 'Pickup City',
          hint: 'Type City Name',
          value: state.pickupCity,
          leadingIcon: Image.asset(
            'assets/images/f31d259897b60d1e77dba5c9332f76ff8fa62152.png',
            width: 28,
            height: 28,
          ),
          trailingIcon: const Icon(
            Icons.close,
            size: 16,
            color: Colors.black54,
          ),
          onChanged: notifier.setPickupCity,
          onClear: notifier.clearPickupCity,
        ),
        const SizedBox(height: 12),
        DateTimeField(
          label: 'Pickup Date',
          value: state.pickupDate != null
              ? DateFormat('dd/MM/yyyy').format(state.pickupDate!)
              : 'DD-MM-YYYY',
          leadingIcon: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.fieldBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/Group (2).png',
                width: 24,
                height: 24,
              ),
            ),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) =>
                  Theme(data: _datePickerTheme(ctx), child: child!),
            );
            if (picked != null) notifier.setPickupDate(picked);
          },
        ),
        const SizedBox(height: 20),
        DateTimeField(
          label: 'Time',
          value: state.time != null ? state.time!.format(context) : 'HH:MM',
          leadingIcon: Image.asset(
            'assets/images/Group (1).png',
            width: 28,
            height: 28,
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (ctx, child) =>
                  Theme(data: _datePickerTheme(ctx), child: child!),
            );
            if (picked != null) notifier.setTime(picked);
          },
        ),
      ],
    );
  }
}

// ────────────────────────────── Airport Form ──────────────────────────────
class _AirportForm extends ConsumerWidget {
  final HomeState state;
  final HomeNotifier notifier;

  const _AirportForm({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = state.airportDirection == AirportDirection.toAirport
        ? 'Pickup City'
        : 'Pickup Airport';

    return Column(
      children: [
        CitySearchField(
          label: label,
          hint: 'Type City Name',
          value: state.pickupCity,
          leadingIcon: Image.asset(
            'assets/images/f31d259897b60d1e77dba5c9332f76ff8fa62152.png',
            width: 28,
            height: 28,
          ),
          trailingIcon: const Icon(
            Icons.close,
            size: 16,
            color: Colors.black54,
          ),
          onChanged: notifier.setPickupCity,
          onClear: notifier.clearPickupCity,
            usePhotonSuggestions:
              state.airportDirection != AirportDirection.fromAirport,
          suggestions: state.airportDirection == AirportDirection.fromAirport
              ? indianAirports
              : indianCities,
        ),
        const SizedBox(height: 20),
        DateTimeField(
          label: 'Pickup Date',
          value: state.pickupDate != null
              ? DateFormat('dd-MM-yyyy').format(state.pickupDate!)
              : 'DD-MM-YYYY',
          leadingIcon: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.fieldBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Image.asset(
                'assets/images/Group (2).png',
                width: 24,
                height: 24,
              ),
            ),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (ctx, child) =>
                  Theme(data: _datePickerTheme(ctx), child: child!),
            );
            if (picked != null) notifier.setPickupDate(picked);
          },
        ),
        const SizedBox(height: 20),
        DateTimeField(
          label: 'Time',
          value: state.time != null ? state.time!.format(context) : 'HH:MM',
          leadingIcon: Image.asset(
            'assets/images/Group (1).png',
            width: 28,
            height: 28,
          ),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
              builder: (ctx, child) =>
                  Theme(data: _datePickerTheme(ctx), child: child!),
            );
            if (picked != null) notifier.setTime(picked);
          },
        ),
      ],
    );
  }
}

// ────────────────────────────── Bottom Illustration ──────────────────────────────
class _BottomIllustration extends StatelessWidget {
  const _BottomIllustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/d3c869509d1814bfb59b39a8be6901d6b17967f0.png',
      fit: BoxFit.contain,
    );
  }
}

// ────────────────────────────── Bottom Nav Bar ──────────────────────────────
class _BottomNavBar extends ConsumerWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navIndexProvider);

    return Container(
      height: 74,
      decoration: const BoxDecoration(color: AppColors.navBg),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                assetPath: 'assets/images/Frame.png',
                label: 'Home',
                selected: navIndex == 0,
                onTap: () => ref.read(navIndexProvider.notifier).state = 0,
              ),
              _NavItem(
                assetPath: 'assets/images/Group (3).png',
                label: 'My Trip',
                selected: navIndex == 1,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ComingSoonScreen(title: 'My Trip'),
                    ),
                  );
                },
              ),
              _NavItem(
                assetPath: 'assets/images/Group (4).png',
                label: 'Account',
                selected: navIndex == 2,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ComingSoonScreen(title: 'Account'),
                    ),
                  );
                },
              ),
              _NavItem(
                assetPath: 'assets/images/Group 31.png',
                label: 'More',
                selected: navIndex == 3,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _ComingSoonScreen(title: 'More'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            assetPath,
            width: 22,
            height: 25,
            color: selected ? Colors.black : Colors.white,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style:
                (selected ? AppTextStyles.navItemActive : AppTextStyles.navItem)
                    .copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  final String title;

  const _ComingSoonScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.navBg,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction_rounded,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Coming Soon',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$title section is under development.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────── Date Picker Theme ──────────────────────────────
ThemeData _datePickerTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primary,
      secondary: AppColors.primary,
      onPrimary: Colors.white,
      onSurface: Colors.black87,
    ),
    timePickerTheme: TimePickerThemeData(
      dayPeriodColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return AppColors.primary;
        }
        return AppColors.fieldBg;
      }),
      dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.white;
        }
        return AppColors.primary;
      }),
      dayPeriodBorderSide: const BorderSide(color: AppColors.primary),
      dialHandColor: AppColors.primary,
      dialBackgroundColor: AppColors.fieldBg,
      entryModeIconColor: AppColors.primary,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
  );
}
