import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class ResultsPage extends StatelessWidget {
  final supabase = Supabase.instance.client;

  ResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Results"),
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
            colors: [Colors.blue[800]!, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<Map<String, List<TimeSlot>>>(
          future: _fetchAvailabilityData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No data available"));
            }

            var availabilityMap = calculateAvailability(snapshot.data!);
            int totalMembers = _calculateTotalMembers(snapshot.data!);

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: availabilityMap.entries.map((entry) {
                String day = entry.key;
                var slots = entry.value;

                // Find the slot with the maximum available members
                TimeSlot? bestSlot;
                int maxAvailable = 0;

                for (var slotEntry in slots.entries) {
                  int availableCount = slotEntry.value.length;
                  if (availableCount > maxAvailable) {
                    maxAvailable = availableCount;
                    bestSlot = slotEntry.key;
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        ...slots.entries.map((slotEntry) {
                          TimeSlot slot = slotEntry.key;
                          Map<String, Duration> members = slotEntry.value;
                          int availableCount = members.keys.toList().length;

                          String formattedStartTime =
                              _formatTime(slot.startTime);
                          String formattedEndTime = _formatTime(slot.endTime);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              color: _getCardColor(),
                              borderRadius: BorderRadius.circular(8.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5.0,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Slot: $formattedStartTime to $formattedEndTime",
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Available: ",
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        Text(
                                          "$availableCount/$totalMembers",
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        ...List.generate(
                                          members.length,
                                          (index) {
                                            String name =
                                                members.keys.toList()[index];
                                            return Text(
                                              "$name: ${_formatDuration(members[name]!)}",
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            );
                                          },
                                        )
                                      ],
                                    ),
                                  ),
                                  // Show tick icon if this slot has the maximum available members
                                  if (slot == bestSlot)
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[800],
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.green,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 10),
                                  // Clock arc showing availability
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.grey[800],
                                      ),
                                      child: CustomPaint(
                                        size: const Size(60, 60),
                                        painter: ArcPainter(
                                          startTime: slot.startTime,
                                          endTime: slot.endTime,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

  Future<Map<String, List<TimeSlot>>> _fetchAvailabilityData() async {
    final data = await supabase.from('free_times').select();

    // Create a map organized by day with a list of time slots
    Map<String, List<TimeSlot>> daySlotsMap = {};

    for (var entry in data) {
      String name = entry['name'];
      String day = entry['day'];
      String startTimeStr = entry['start_time'];
      String endTimeStr = entry['end_time'];

      Duration startTime = _parseTime(startTimeStr);
      Duration endTime = _parseTime(endTimeStr);

      TimeSlot timeSlot = TimeSlot(day, startTime, endTime, name);

      // Add the time slot to the appropriate day
      daySlotsMap.putIfAbsent(day, () => []);
      daySlotsMap[day]!.add(timeSlot);
    }

    return daySlotsMap;
  }

  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  String _formatTime(Duration time) {
    int hours = time.inHours % 12;
    int minutes = time.inMinutes.remainder(60);
    String period = time.inHours >= 12 ? 'PM' : 'AM';
    return '${hours == 0 ? 12 : hours}:${minutes.toString().padLeft(2, '0')} $period';
  }

  Color _getCardColor() {
    // Generate a random color for the card
    Random random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(100),
      random.nextInt(100),
      random.nextInt(100),
    ).withOpacity(0.7);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString();

    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));

    List<String> parts = [];
    if (duration.inHours > 0) {
      parts.add('$hours hour${duration.inHours > 1 ? 's' : ''}');
    }
    if (duration.inMinutes.remainder(60) > 0) {
      parts.add(
          '$minutes minute${duration.inMinutes.remainder(60) > 1 ? 's' : ''}');
    }

    return parts.join(', ');
  }

  Map<String, Map<TimeSlot, Map<String, Duration>>> calculateAvailability(
      Map<String, List<TimeSlot>> daySlotsMap) {
    // Final map to store availability information
    Map<String, Map<TimeSlot, Map<String, Duration>>> availabilityMap = {};

    // Iterate through each day's slots
    for (var dayEntry in daySlotsMap.entries) {
      String day = dayEntry.key;
      List<TimeSlot> timeSlotList = dayEntry.value;

      // Initialize the availability map for this day
      availabilityMap.putIfAbsent(day, () => {});

      // Compare each slot with every other slot for overlaps
      for (int i = 0; i < timeSlotList.length; i++) {
        TimeSlot slot1 = timeSlotList[i];

        // Initialize the current slot with the member who owns it
        availabilityMap[day]!.putIfAbsent(slot1, () => {});

        // Store the member and their overlap duration
        availabilityMap[day]![slot1]![slot1.memberName] =
            slot1.endTime - slot1.startTime;

        for (int j = 0; j < timeSlotList.length; j++) {
          if (i == j) continue; // Skip comparing the same slot

          TimeSlot slot2 = timeSlotList[j];

          // Check if the two slots overlap
          Duration overlap = _slotsOverlap(slot1, slot2);
          if (overlap != Duration.zero) {
            // Add slot2's member to slot1's list if not already present
            Map<String, Duration> slot1Members = availabilityMap[day]![slot1]!;
            if (!slot1Members.containsKey(slot2.memberName)) {
              slot1Members[slot2.memberName] =
                  Duration.zero; // Initialize duration
            }
            // Update the overlap duration
            slot1Members[slot2.memberName] = overlap;
          }
        }
      }
    }

    return availabilityMap;
  }

  int _calculateTotalMembers(Map<String, List<TimeSlot>> daySlotsMap) {
    // Use a Set to collect unique member names
    Set<String> uniqueMembers = {};

    // Iterate through each day's slots
    for (var dayEntry in daySlotsMap.entries) {
      List<TimeSlot> timeSlotList = dayEntry.value;

      // Iterate through the time slots to collect unique member names
      for (var timeSlot in timeSlotList) {
        uniqueMembers.add(timeSlot.memberName);
      }
    }

    // Return the total number of unique members
    return uniqueMembers.length;
  }
}

Duration _slotsOverlap(TimeSlot slot1, TimeSlot slot2) {
  // If both slots are the same
  if (slot1.startTime == slot2.startTime && slot1.endTime == slot2.endTime) {
    return slot1.endTime - slot1.startTime;
  }

  // Check if there's an intersection at all
  if ((slot1.endTime > slot2.startTime && slot1.startTime < slot2.endTime) ||
      (slot2.endTime > slot1.startTime && slot2.startTime < slot1.endTime)) {
    print([
      "INTERSECTION",
      slot1.startTime,
      slot1.endTime,
      slot2.startTime,
      slot2.endTime
    ]);

    // Case 1: One slot is completely inside the other
    if (slot1.startTime > slot2.startTime && slot1.endTime < slot2.endTime) {
      print([
        "CASE 1",
        slot1.startTime,
        slot1.endTime,
        slot2.startTime,
        slot2.endTime
      ]);

      return (slot1.endTime - slot1.startTime);
    } else if (slot2.startTime > slot1.startTime &&
        slot2.endTime < slot1.endTime) {
      print([
        "CASE 2",
        slot1.startTime,
        slot1.endTime,
        slot2.startTime,
        slot2.endTime
      ]);

      return (slot2.endTime - slot2.startTime);
    }

    // Case 2: Partial overlap
    if (slot2.endTime >= slot1.endTime) {
      // Slot2 comes after Slot1
      return (slot2.startTime - slot1.endTime).abs();
    } else {
      // Slot1 comes after Slot2
      return (slot2.endTime - slot1.startTime).abs();
    }
  }

  // No overlap, return a zero duration
  return Duration.zero;
}

class ArcPainter extends CustomPainter {
  final Duration startTime;
  final Duration endTime;

  ArcPainter({required this.startTime, required this.endTime});

  @override
  void paint(Canvas canvas, Size size) {
    double radius = size.width / 2;
    double centerX = radius;
    double centerY = radius;

    // Convert Duration to radians for the arc
    double startAngle = _getRadians(startTime);
    double sweepAngle = _getRadians(endTime) - startAngle;

    Paint arcPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    // Draw the pizza slice arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      startAngle,
      sweepAngle,
      true,
      arcPaint,
    );

    // Draw clock ticks
    Paint tickPaint = Paint()..color = Colors.white;

    // Large ticks
    for (int i = 0; i < 12; i++) {
      double angle = (i / 12) * 2 * pi; // Angle for each hour
      double startX = centerX + (radius - 10) * cos(angle);
      double startY = centerY + (radius - 10) * sin(angle);
      double endX = centerX + radius * cos(angle);
      double endY = centerY + radius * sin(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }
  }

  double _getRadians(Duration time) {
    double hours = time.inHours.toDouble();
    double minutes = time.inMinutes.remainder(60) / 60;
    double totalHours = hours + minutes;
    return (totalHours / 12) * (2 * pi) - pi / 2; // Convert to radians
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class TimeSlot {
  final String day;
  final Duration startTime;
  final Duration endTime;
  final String memberName; // Add the member's name

  TimeSlot(this.day, this.startTime, this.endTime, this.memberName);
}
