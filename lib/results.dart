import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberAvailability {
  final String name;
  final String day;
  final String startTime;
  final String endTime;

  MemberAvailability(this.name, this.day, this.startTime, this.endTime);
}

class ResultsPage extends StatelessWidget {
  final supabase = Supabase.instance.client;

  ResultsPage({super.key});

  Future<Map<String, Map<String, List<Map<String, dynamic>>>>>
      _fetchCommonAvailability() async {
    final data = await supabase.from('free_times').select();

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

    return findCommonAvailability(userAvailabilities);
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

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
        child:
            FutureBuilder<Map<String, Map<String, List<Map<String, dynamic>>>>>(
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
                final slots =
                    entry.value['commonSlots'] as List<Map<String, dynamic>>;

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
                        ...slots.map((slot) {
                          final time =
                              '${_formatTime(slot['start'])} - ${_formatTime(slot['end'])}';
                          final members =
                              (slot['members'] as List<String>).join(', ');
                          final count =
                              '${slot['count']}/${slot['total']} members';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Members: $members',
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                count,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                            ],
                          );
                        }),
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

  Map<String, Map<String, List<Map<String, dynamic>>>> findCommonAvailability(
      Map<String, Map<String, List<List<TimeOfDay>>>> userAvailabilities) {
    Map<String, Map<String, List<Map<String, dynamic>>>> result = {};

    // Get all possible days
    final days = userAvailabilities.values.first.keys.toList();

    for (String day in days) {
      List<List<TimeOfDay>> allTimeSlots = [];

      // Collect all time slots for that day
      userAvailabilities.forEach((name, availabilities) {
        final timeSlots = availabilities[day];
        if (timeSlots != null) {
          for (var timeSlot in timeSlots) {
            allTimeSlots.add(timeSlot);
          }
        }
      });

      // Find the common overlapping times for groups of users
      List<Map<String, dynamic>> commonSlots = [];

      for (var i = 0; i < allTimeSlots.length; i++) {
        List<String> availableMembers = [];
        TimeOfDay start = allTimeSlots[i][0];
        TimeOfDay end = allTimeSlots[i][1];

        userAvailabilities.forEach((name, availabilities) {
          if (availabilities[day] != null) {
            for (var timeSlot in availabilities[day]!) {
              if (timeOverlap(start, end, timeSlot[0], timeSlot[1])) {
                availableMembers.add(name);
              }
            }
          }
        });

        if (availableMembers.isNotEmpty) {
          commonSlots.add({
            'start': start,
            'end': end,
            'members': availableMembers,
            'count': availableMembers.length,
            'total': userAvailabilities.keys.length
          });
        }
      }

      if (commonSlots.isNotEmpty) {
        result[day] = {'commonSlots': commonSlots};
      }
    }

    return result;
  }
}
