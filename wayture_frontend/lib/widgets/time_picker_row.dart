import 'package:flutter/material.dart';
import 'package:wayture/config/theme.dart';

enum DepartureOption { leaveNow, in30min, in1hour, pickTime }

class TimePickerRow extends StatefulWidget {
  final TimeOfDay? selectedTime;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  const TimePickerRow({
    super.key,
    this.selectedTime,
    required this.onTimeChanged,
  });

  @override
  State<TimePickerRow> createState() => _TimePickerRowState();
}

class _TimePickerRowState extends State<TimePickerRow> {
  DepartureOption _selectedOption = DepartureOption.leaveNow;

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  TimeOfDay _addMinutes(int minutes) {
    final now = TimeOfDay.now();
    final totalMinutes = now.hour * 60 + now.minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  void _selectOption(DepartureOption option) async {
    if (mounted) setState(() => _selectedOption = option);

    switch (option) {
      case DepartureOption.leaveNow:
        widget.onTimeChanged(null);
      case DepartureOption.in30min:
        widget.onTimeChanged(_addMinutes(30));
      case DepartureOption.in1hour:
        widget.onTimeChanged(_addMinutes(60));
      case DepartureOption.pickTime:
        final picked = await showTimePicker(
          context: context,
          initialTime: widget.selectedTime ?? TimeOfDay.now(),
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
          widget.onTimeChanged(picked);
        } else {
          // User cancelled — revert to Leave Now
          if (mounted) setState(() => _selectedOption = DepartureOption.leaveNow);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "When" label
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'When',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (widget.selectedTime != null)
                    Text(
                      'Departing at ${_formatTime(widget.selectedTime!)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick option chips
              Row(
                children: [
                  _optionChip('Leave Now', DepartureOption.leaveNow),
                  const SizedBox(width: 6),
                  _optionChip('In 30 min', DepartureOption.in30min),
                  const SizedBox(width: 6),
                  _optionChip('In 1 hour', DepartureOption.in1hour),
                  const SizedBox(width: 6),
                  _optionChip('Pick Time', DepartureOption.pickTime,
                      icon: Icons.access_time),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _optionChip(String label, DepartureOption option,
      {IconData? icon}) {
    final isSelected = _selectedOption == option;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectOption(option),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.white.withAlpha(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    color: isSelected ? Colors.white : Colors.white38,
                    size: 12),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
