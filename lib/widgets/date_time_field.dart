import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final Widget leadingIcon;
  final VoidCallback onTap;

  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.leadingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.fieldBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            leadingIcon,
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppTextStyles.fieldLabel),
                Text(value, style: AppTextStyles.fieldHint),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Dual date field for round trip (From Date | Calendar Icon | To Date)
class DualDateField extends StatelessWidget {
  final String fromDate;
  final String toDate;
  final VoidCallback onFromDateTap;
  final VoidCallback onToDateTap;

  const DualDateField({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.onFromDateTap,
    required this.onToDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // From Date
        Expanded(
          child: GestureDetector(
            onTap: onFromDateTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From Date',
                  style: AppTextStyles.fieldLabel.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  fromDate,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Calendar icon in circle
        Container(
          width: 51,
          height: 51,
          decoration: const BoxDecoration(
            color: AppColors.fieldBg,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Image.asset(
              'assets/images/Group (2).png',
              width: 28,
              height: 28,
            ),
          ),
        ),

        // To Date
        Expanded(
          child: GestureDetector(
            onTap: onToDateTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'To Date',
                  style: AppTextStyles.fieldLabel.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  toDate,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
