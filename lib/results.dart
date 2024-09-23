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
        backgroundColor: Colors.blue[800]!,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[800]!, Colors.black],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<MemberAvailability>>(
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
                          List<String> members = slotEntry.value;
                          int availableCount = members.length;
                          int totalMembers = 4; // Adjust this as needed

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
                                        Text(
                                          "Members: ${members.join(', ')}",
                                          style: const TextStyle(fontSize: 16),
                                        ),
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
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[800],
                                    ),
                                    child: CustomPaint(
                                      size: Size(60, 60),
                                      painter: ArcPainter(
                                        startTime: slot.startTime,
                                        endTime: slot.endTime,
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

  Future<List<MemberAvailability>> _fetchAvailabilityData() async {
    final data = await supabase.from('free_times').select();

    List<MemberAvailability> members = [];
    for (var entry in data) {
      String name = entry['name'];
      String day = entry['day'];
      String startTimeStr = entry['start_time'];
      String endTimeStr = entry['end_time'];

      Duration startTime = _parseTime(startTimeStr);
      Duration endTime = _parseTime(endTimeStr);

      var member = members.firstWhere(
        (m) => m.name == name,
        orElse: () => MemberAvailability(name, []),
      );

      if (!members.contains(member)) {
        members.add(member);
      }

      member.timeSlots.add(TimeSlot(day, startTime, endTime));
    }
    return members;
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
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    ).withOpacity(0.7);
  }

  Map<String, Map<TimeSlot, List<String>>> calculateAvailability(
      List<MemberAvailability> members) {
    Map<String, Map<TimeSlot, List<String>>> availabilityMap = {};

    for (var member in members) {
      for (var timeSlot in member.timeSlots) {
        availabilityMap.putIfAbsent(timeSlot.day, () => {});
        var daySlots = availabilityMap[timeSlot.day]!;

        for (var currentSlot in daySlots.keys) {
          if (timeSlot.startTime.inMinutes < currentSlot.endTime.inMinutes &&
              timeSlot.endTime.inMinutes > currentSlot.startTime.inMinutes) {
            daySlots[currentSlot]!.add(member.name);
          }
        }

        if (!daySlots.containsKey(timeSlot)) {
          daySlots[timeSlot] = [member.name];
        }
      }
    }

    return availabilityMap;
  }
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

  TimeSlot(this.day, this.startTime, this.endTime);
}

class MemberAvailability {
  final String name;
  final List<TimeSlot> timeSlots;

  MemberAvailability(this.name, this.timeSlots);
}
