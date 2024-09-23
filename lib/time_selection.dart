// ignore_for_file: use_build_context_synchronously

import 'package:availability_scanner/results.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimeSelectionPage extends StatefulWidget {
  final String userName;

  const TimeSelectionPage({super.key, required this.userName});

  @override
  // ignore: library_private_types_in_public_api
  _TimeSelectionPageState createState() => _TimeSelectionPageState();
}

class _TimeSelectionPageState extends State<TimeSelectionPage> {
  final supabase = Supabase.instance.client;

  final Map<String, List<TimeOfDayRange>> _availability = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  bool _isLoading = false; // Loading state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Available Times'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[900]!, Colors.black],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[900]!,
              Colors.black,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Hello, ${widget.userName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.extent(
                  maxCrossAxisExtent: 400,
                  children: _availability.keys.map((day) {
                    return _buildDayColumn(day);
                  }).toList(),
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAvailability,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayColumn(String day) {
    return Card(
      color: Colors.blue[600]!.withOpacity(0.7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              day,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: ListView(
                  shrinkWrap: true,
                  children: _availability[day]!.asMap().entries.map((entry) {
                    int index = entry.key;
                    TimeOfDayRange range = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              '${range.start.format(context)} - ${range.end.format(context)}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () => _editTimeSlot(context, day, index),
                          ),
                          const SizedBox(width: 5),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTimeSlot(day, index),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _addTimeSlot(context, day),
          ),
        ],
      ),
    );
  }

  Future<void> _addTimeSlot(BuildContext context, String day) async {
    final TimeOfDay? start = await _selectTime(context, 'Select Start Time');
    if (start == null) return;
    final TimeOfDay? end = await _selectTime(context, 'Select End Time');
    if (end == null) return;

    setState(() {
      _availability[day]?.add(TimeOfDayRange(start: start, end: end));
    });
  }

  Future<void> _editTimeSlot(
      BuildContext context, String day, int index) async {
    final TimeOfDayRange currentRange = _availability[day]![index];

    final TimeOfDay? start = await _selectTime(context, 'Edit Start Time',
        initialTime: currentRange.start);
    if (start == null) return;
    final TimeOfDay? end = await _selectTime(context, 'Edit End Time',
        initialTime: currentRange.end);
    if (end == null) return;

    setState(() {
      _availability[day]![index] = TimeOfDayRange(start: start, end: end);
    });
  }

  void _deleteTimeSlot(String day, int index) {
    setState(() {
      _availability[day]!.removeAt(index);
    });
  }

  Future<TimeOfDay?> _selectTime(BuildContext context, String title,
      {TimeOfDay? initialTime}) {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      helpText: title,
    );
  }

  void _submitAvailability() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      for (var entry in _availability.entries) {
        final day = entry.key;
        final times = entry.value;
        await Future.wait(List.generate(
            times.length,
            (index) => supabase.from('free_times').insert({
                  'name': widget.userName,
                  'day': day,
                  'start_time': times[index].start.format(context),
                  'end_time': times[index].end.format(context),
                })));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability submitted successfully!')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsPage(),
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Stop loading
      });
    }
  }
}

class TimeOfDayRange {
  final TimeOfDay start;
  final TimeOfDay end;

  TimeOfDayRange({required this.start, required this.end});
}
