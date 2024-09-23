import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  final supabase = Supabase.instance.client;
  Map<String, Map<String, List<Map<String, dynamic>>>> groupedEntries = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEntries();
  }

  Future<void> _fetchEntries() async {
    try {
      final data = await supabase.from('free_times').select();

      final List<Map<String, dynamic>> rawEntries =
          data.map((e) => Map<String, dynamic>.from(e)).toList();

      // Group entries by 'name' and then by 'day'
      Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
      for (var entry in rawEntries) {
        String name = entry['name'];
        String day = entry['day'];

        grouped.putIfAbsent(name, () => {});
        grouped[name]!.putIfAbsent(day, () => []);
        grouped[name]![day]!.add(entry);
      }

      setState(() {
        groupedEntries = grouped;
        _isLoading = false;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching entries: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Entries'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedEntries.isEmpty
              ? const Center(child: Text('No available times found yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: groupedEntries.length,
                  itemBuilder: (context, index) {
                    String name = groupedEntries.keys.elementAt(index);
                    return _buildNameCard(name, groupedEntries[name]!);
                  },
                ),
    );
  }

  // Build a card for each name
  Widget _buildNameCard(
      String name, Map<String, List<Map<String, dynamic>>> days) {
    return Card(
      color: Colors.blue[900]!.withOpacity(0.7),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: $name',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.keys
                  .map((day) => _buildDayCard(day, days[day]!))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Build a subcard for each day, ensuring it takes full width
  Widget _buildDayCard(String day, List<Map<String, dynamic>> dayEntries) {
    return SizedBox(
      width: double.infinity, // Ensure full width
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: [
                Colors.blue[800]!,
                Colors.blue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day: $day',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dayEntries
                      .map((entry) => _buildTimeEntry(entry))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build individual time entries
  Widget _buildTimeEntry(Map<String, dynamic> entry) {
    final String startTime = _formatTime(entry['start_time']);
    final String endTime = _formatTime(entry['end_time']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        '$startTime - $endTime',
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

// Format time from 24-hour to 12-hour format with minutes and spacing
  String _formatTime(String time) {
    final DateTime dateTime =
        DateTime.parse('2022-01-01 $time'); // Use a dummy date
    String hour =
        dateTime.hour % 12 == 0 ? '12' : (dateTime.hour % 12).toString();
    String minute = dateTime.minute
        .toString()
        .padLeft(2, '0'); // Ensure two digits for minutes
    String period = dateTime.hour < 12 ? 'AM' : 'PM';

    return "$hour:$minute $period"; // Add space before AM/PM
  }
}
