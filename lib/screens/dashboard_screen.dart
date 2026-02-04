import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';
import 'qr_screen.dart';
import 'sections_screen.dart';
import '../services/api_service.dart';
import '../services/session_state.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  // Countdown timers
  Duration currentClassTimeLeft = Duration.zero;
  Duration nextClassTimeLeft = Duration.zero;

  DateTime? currentClassEnd;
  DateTime? nextClassStart;

  // Schedule data
  Map<String, dynamic>? currentClass;
  Map<String, dynamic>? nextClass;
  bool _isLoading = true;
  String? _errorMessage;

  // Stats data
  int _totalSections = 0;
  int _totalSubjects = 0;
  int _totalStudents = 0;
  Map<String, dynamic> _groupedSections = {};

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final instructorId = await StorageService.getInstructorId();

      if (instructorId == null) {
        setState(() {
          _errorMessage = 'Instructor ID not found. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final result = await _apiService.getInstructorSchedules(instructorId);

      if (result['success']) {
        // Extract all schedules from the list
        List<Map<String, dynamic>> allSchedules = [];
        final List<dynamic> schedulesData = result['data'] as List<dynamic>;

        // Group by section for the stats
        Map<String, List<Map<String, dynamic>>> groupedSections = {};

        for (var item in schedulesData) {
          // Adapt the item structure to our needs

          // Extract section info
          var sectionData = item['section'];
          String sectionName = sectionData?['name'] ?? 'Unknown';
          int sectionId = sectionData?['id'] ?? 0;

          // Initialize section if not exists
          if (!groupedSections.containsKey(sectionName)) {
            groupedSections[sectionName] = [];
          }

          // Extract subject info
          var subjectData = item['subject'];
          String subjectName = subjectData?['name'] ?? 'Unknown Subject';
          String subjectCode = subjectData?['code'] ?? 'N/A';
          int subjectId = subjectData?['id'] ?? 0;

          // Extract classroom info
          var classroomData = item['classroom'];
          String room = classroomData?['name'] ?? '';

          // Extract schedule time
          String timeIn = item['timeIn'] ?? '';
          String timeOut = item['timeOut'] ?? '';
          String dayOfWeek = item['dayOfWeek'] ?? '';

          String scheduleStr = '';
          if (dayOfWeek.isNotEmpty && timeIn.isNotEmpty && timeOut.isNotEmpty) {
            String formattedTimeIn = timeIn.length >= 5
                ? timeIn.substring(0, 5)
                : timeIn;
            String formattedTimeOut = timeOut.length >= 5
                ? timeOut.substring(0, 5)
                : timeOut;
            scheduleStr = '$dayOfWeek $formattedTimeIn-$formattedTimeOut';
          }

          final scheduleItem = {
            'sectionId': sectionId,
            'sectionName': sectionName,
            'subjectId': subjectId,
            'subjectName': subjectName,
            'subjectCode': subjectCode,
            'name': subjectName,
            'code': subjectCode,
            'schedule': scheduleStr,
            'room': room,
            'scheduleId': item['id'],
            'startDateTime': null, // Will be calculated
            'endDateTime': null, // Will be calculated
          };

          groupedSections[sectionName]!.add(scheduleItem);
          allSchedules.add(scheduleItem);
        }

        _groupedSections = groupedSections;

        // Calculate stats
        _totalSections = groupedSections.keys.length;
        _totalSubjects = allSchedules.length;

        // Load student count
        await _loadStudentCount();

        _findCurrentAndNextClass(allSchedules);

        setState(() {
          _isLoading = false;
        });

        // Start countdown timer
        _startCountdown();
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load schedules';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentCount() async {
    int totalStudents = 0;

    // Get unique section IDs from all subjects
    Set<int> uniqueSectionIds = {};

    for (var subjects in _groupedSections.values) {
      final subjectList = List<Map<String, dynamic>>.from(subjects);
      for (var subject in subjectList) {
        if (subject['sectionId'] != null) {
          uniqueSectionIds.add(subject['sectionId']);
        }
      }
    }

    // Fetch student count for each unique section
    for (var sectionId in uniqueSectionIds) {
      final result = await _apiService.getSectionStudents(sectionId);
      if (result['success']) {
        final students = result['data'] as List;
        totalStudents += students.length;
      }
    }

    setState(() {
      _totalStudents = totalStudents;
    });
  }

  void _findCurrentAndNextClass(List<Map<String, dynamic>> allSchedules) {
    // Check global session state first
    if (SessionState.instance.isActive) {
      final sessionSchedule = SessionState.instance.currentSchedule;
      if (sessionSchedule != null) {
        setState(() {
          currentClass = {
            'subjectName': sessionSchedule['name'],
            'subjectCode': sessionSchedule['code'],
            'room': sessionSchedule['room'],
            'schedule': sessionSchedule['time'],
            'scheduleId': sessionSchedule['id'],
          };
          nextClass = null;
          currentClassEnd = null;
        });
        return;
      }
    }

    final now = DateTime.now();
    final currentDay = DateFormat('EEEE').format(now); // e.g., "Monday"

    Map<String, dynamic>? foundCurrentClass;
    Map<String, dynamic>? foundNextClass;
    DateTime? foundCurrentClassEnd;
    DateTime? foundNextClassStart;

    // Filter schedules for today
    final todaySchedules = allSchedules.where((schedule) {
      final scheduleStr = schedule['schedule']?.toString() ?? '';
      return scheduleStr.startsWith(currentDay);
    }).toList();

    // Parse and sort today's schedules by time
    List<Map<String, dynamic>> parsedSchedules = [];

    for (var schedule in todaySchedules) {
      final scheduleStr = schedule['schedule']?.toString() ?? '';
      final parts = scheduleStr.split(' ');

      if (parts.length < 2) continue;

      final timeRange = parts[1]; // e.g., "08:00-10:00"
      final timeParts = timeRange.split('-');

      if (timeParts.length != 2) continue;

      try {
        final startTime = _parseTime(timeParts[0]);
        final endTime = _parseTime(timeParts[1]);

        final startDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          startTime.hour,
          startTime.minute,
        );
        final endDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          endTime.hour,
          endTime.minute,
        );

        parsedSchedules.add({
          ...schedule,
          'startDateTime': startDateTime,
          'endDateTime': endDateTime,
          'startTime': startTime,
          'endTime': endTime,
        });
      } catch (e) {
        print('Error parsing time for schedule: $scheduleStr - $e');
      }
    }

    // Sort by start time
    parsedSchedules.sort(
      (a, b) => (a['startDateTime'] as DateTime).compareTo(
        b['startDateTime'] as DateTime,
      ),
    );

    // Find current class (ongoing now)
    for (var schedule in parsedSchedules) {
      final startDateTime = schedule['startDateTime'] as DateTime;
      final endDateTime = schedule['endDateTime'] as DateTime;

      if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
        foundCurrentClass = schedule;
        foundCurrentClassEnd = endDateTime;
        break;
      }
    }

    // Find next class (starts after now)
    for (var schedule in parsedSchedules) {
      final startDateTime = schedule['startDateTime'] as DateTime;

      if (now.isBefore(startDateTime)) {
        // Skip if this is already set as current class
        if (foundCurrentClass != null &&
            schedule['scheduleId'] == foundCurrentClass['scheduleId']) {
          continue;
        }

        foundNextClass = schedule;
        foundNextClassStart = startDateTime;
        break;
      }
    }

    // If no current class found, but there are future classes today
    if (foundCurrentClass == null &&
        foundNextClass == null &&
        parsedSchedules.isNotEmpty) {
      // Check if there's a class coming up today
      for (var schedule in parsedSchedules) {
        final startDateTime = schedule['startDateTime'] as DateTime;
        if (now.isBefore(startDateTime)) {
          foundNextClass = schedule;
          foundNextClassStart = startDateTime;
          break;
        }
      }
    }

    setState(() {
      currentClass = foundCurrentClass;
      nextClass = foundNextClass;
      currentClassEnd = foundCurrentClassEnd;
      nextClassStart = foundNextClassStart;
    });
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    throw FormatException('Invalid time format: $timeStr');
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final now = DateTime.now();

        // Update current class countdown
        if (SessionState.instance.isActive &&
            SessionState.instance.startTime != null) {
          currentClassTimeLeft = now.difference(
            SessionState.instance.startTime!,
          );
        } else if (currentClassEnd != null && now.isBefore(currentClassEnd!)) {
          currentClassTimeLeft = currentClassEnd!.difference(now);
        } else {
          currentClassTimeLeft = Duration.zero;
        }

        // Update next class countdown
        if (nextClassStart != null && now.isBefore(nextClassStart!)) {
          nextClassTimeLeft = nextClassStart!.difference(now);
        } else {
          nextClassTimeLeft = Duration.zero;
        }

        setState(() {});
        _startCountdown();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEyeProtection = SettingsService.instance.isEyeProtectionMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Image.asset(
                      'lib/images/aclc_logo.png',
                      width: 50,
                      height: 50,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Teacher Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Section Header
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E3A8A),
                                fontSize: 20,
                              ),
                        ),
                        const SizedBox(height: 16),
                        // Overview Cards - 2x2 Grid
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOverviewCard(
                                    'Sections',
                                    _totalSections.toString(),
                                    Icons.class_outlined,
                                    const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildOverviewCard(
                                    'Subjects',
                                    _totalSubjects.toString(),
                                    Icons.book_outlined,
                                    const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOverviewCard(
                                    'Students',
                                    _totalStudents.toString(),
                                    Icons.people_outline,
                                    const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildOverviewCard(
                                    'Classes',
                                    _totalSubjects.toString(),
                                    Icons.school_outlined,
                                    const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Schedule Section
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          )
                        else if (_errorMessage != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _loadSchedules,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          Text(
                            'Current Class',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E3A8A),
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 16),

                          if (currentClass != null)
                            _buildClassCard(
                              currentClass!['subjectName'] ?? 'Unknown Subject',
                              currentClass!['subjectCode'] ?? 'N/A',
                              '${currentClass!['room'] ?? 'TBA'} • ${_formatScheduleTime(currentClass!['schedule'])}',
                              currentClass!['schedule'] ?? '',
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(DateTime.now()),
                              _formatDuration(currentClassTimeLeft),
                              true,
                            )
                          else
                            _buildNoClassCard('No ongoing class at the moment'),

                          const SizedBox(height: 16),

                          Text(
                            'Next Class',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E3A8A),
                                  fontSize: 20,
                                ),
                          ),
                          const SizedBox(height: 16),

                          if (nextClass != null)
                            _buildClassCard(
                              nextClass!['subjectName'] ?? 'Unknown Subject',
                              nextClass!['subjectCode'] ?? 'N/A',
                              '${nextClass!['room'] ?? 'TBA'} • ${_formatScheduleTime(nextClass!['schedule'])}',
                              nextClass!['schedule'] ?? '',
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(DateTime.now()),
                              _formatDuration(nextClassTimeLeft),
                              false,
                            )
                          else
                            _buildNoClassCard('No upcoming class today'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          selectedItemColor: const Color(0xFF3B82F6),
          unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          onTap: (index) {
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AttendanceScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(builder: (context) => const QrScreen()),
                  )
                  .then((_) => _loadSchedules());
            } else if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SectionsScreen()),
              );
            } else if (index == 4) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: 'Sections',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  String _formatScheduleTime(String? schedule) {
    if (schedule == null || schedule.isEmpty) return '';

    final parts = schedule.split(' ');
    if (parts.length < 2) return '';

    final timeRange = parts[1];
    final times = timeRange.split('-');
    if (times.isEmpty) return '';

    try {
      final time = _parseTime(times[0]);
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return times[0];
    }
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: Colors.black, size: 18),
          ),
          Flexible(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(
    String course,
    String code,
    String location,
    String schedule,
    String date,
    String countdown,
    bool isCurrent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent
              ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
              : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (isCurrent ? const Color(0xFF1E3A8A) : const Color(0xFF3B82F6))
                    .withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCurrent ? 'Current Class' : 'Next Class',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isCurrent)
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      countdown,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.class_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          code,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            location.split('•')[0].trim(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          schedule,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
