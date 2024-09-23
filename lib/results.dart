import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResultsPage extends StatelessWidget {
  final supabase = Supabase.instance.client;

  ResultsPage({super.key});

  Future<Map<String, List<List<TimeOfDay>>>> _fetchCommonAvailability() async {
    final data = await supabase.from('free_times').select();

    print(data);

    if (data.isEmpty) {
      return {}; // Return an empty map if there are no entries
    }

    Map<String, Map<String, List<List<TimeOfDay>>>> userAvailabilities = {};

    for (var entry in data) {
      String name = entry['name'];
      String day = entry['day'];
      TimeOfDay start = _parseTime(entry['start_time']);
      TimeOfDay end = _parseTime(entry['end_time']);

      if (!userAvailabilities.containsKey(name)) {
        userAvailabilities[name] = {};
      }

      if (!userAvailabilities[name]!.containsKey(day)) {
        userAvailabilities[name]![day] = [];
      }

      userAvailabilities[name]![day]!.add([start, end]);
    }

    List<Map<String, List<List<TimeOfDay>>>> userAvailabilitiesList =
        userAvailabilities.values.map((user) => user).toList();

    if (userAvailabilitiesList.isEmpty) {
      return {}; // Return an empty map if no user availabilities were found
    }

    return findCommonAvailability(userAvailabilitiesList);
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Common Availability'),
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
            colors: [Colors.blue[900]!, Colors.black],
          ),
        ),
        child: FutureBuilder<Map<String, List<List<TimeOfDay>>>>(
          future: _fetchCommonAvailability(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('No available times found yet.',
                    style: TextStyle(color: Colors.white)),
              );
            }

            final commonAvailability = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: commonAvailability.entries.map((entry) {
                final day = entry.key;
                final times = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  color: Colors.blue[800],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        ...times.map((timeRange) {
                          return Text(
                            '${_formatTime(timeRange[0])} - ${_formatTime(timeRange[1])}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour =
        time.hour % 12 == 0 ? 12 : time.hour % 12; // Convert to 12-hour format
    final minute = time.minute.toString().padLeft(2, '0');
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  bool timeOverlap(
      TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    int start1Minutes = start1.hour * 60 + start1.minute;
    int end1Minutes = end1.hour * 60 + end1.minute;
    int start2Minutes = start2.hour * 60 + start2.minute;
    int end2Minutes = end2.hour * 60 + end2.minute;

    return start1Minutes < end2Minutes && start2Minutes < end1Minutes;
  }

  List<TimeOfDay> findOverlap(
      TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    if (!timeOverlap(start1, end1, start2, end2)) {
      return []; // No overlap
    }

    TimeOfDay overlapStart =
        (start1.hour * 60 + start1.minute) > (start2.hour * 60 + start2.minute)
            ? start1
            : start2;
    TimeOfDay overlapEnd =
        (end1.hour * 60 + end1.minute) < (end2.hour * 60 + end2.minute)
            ? end1
            : end2;

    return [overlapStart, overlapEnd];
  }

  Map<String, List<List<TimeOfDay>>> findCommonAvailability(
      List<Map<String, List<List<TimeOfDay>>>> userAvailabilities) {
    Map<String, List<List<TimeOfDay>>> commonAvailability = {};

    for (String day in userAvailabilities.first.keys) {
      List<List<TimeOfDay>> commonIntervals =
          userAvailabilities.first[day] ?? [];

      for (int i = 1; i < userAvailabilities.length; i++) {
        Map<String, List<List<TimeOfDay>>> nextUser = userAvailabilities[i];
        List<List<TimeOfDay>> nextUserIntervals = nextUser[day] ?? [];

        List<List<TimeOfDay>> newCommonIntervals = [];

        for (var interval1 in commonIntervals) {
          for (var interval2 in nextUserIntervals) {
            var overlap = findOverlap(
                interval1[0], interval1[1], interval2[0], interval2[1]);
            if (overlap.isNotEmpty) {
              newCommonIntervals.add(overlap);
            }
          }
        }

        commonIntervals = newCommonIntervals;

        if (commonIntervals.isEmpty) break;
      }

      if (commonIntervals.isNotEmpty) {
        commonAvailability[day] = commonIntervals;
      }
    }

    return commonAvailability;
  }
}
