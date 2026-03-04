import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

class TimePickerRow extends StatelessWidget {
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  const TimePickerRow({
    super.key,
    this.selectedTime,
    required this.onTimeChanged,
  });

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Now';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Depart at',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: selectedTime ?? TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: Color(0xFF1A1A2E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                onTimeChanged(picked);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withAlpha(100),
                ),
              ),
              child: Text(
                _formatTime(selectedTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Spacer(),
          if (selectedTime != null)
            GestureDetector(
              onTap: () => onTimeChanged(null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white38, size: 14),
              ),
            ),
        ],
      ),
    );
  }
}
