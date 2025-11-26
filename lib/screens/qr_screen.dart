import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/session_state.dart';
// import 'dart:convert'; // Removed unused import
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'sections_screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();

  String? _selectedSchedule;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          _errorMessage = 'Instructor ID not found';
          _isLoading = false;
        });
        return;
      }

      final result = await _apiService.getInstructorSchedules(instructorId);

      if (result['success']) {
        final List<dynamic> data = result['data'];
        final List<Map<String, dynamic>> loadedSchedules = [];

        // Get day name for selected date (e.g., "Monday")
        final dayName = DateFormat('EEEE').format(_selectedDate);
        print('📅 Selected Date: $_selectedDate');
        print('📅 Day Name: $dayName');
        print('📦 Total Schedules Fetched: ${data.length}');

        for (var item in data) {
          // Check if schedule matches selected day
          final String scheduleDay = item['dayOfWeek'] ?? '';
          print(
            '  - Found schedule: ${item['subject']?['code']} on $scheduleDay',
          );

          // REMOVED FILTER: Show all schedules as per user request
          // if (scheduleDay.toLowerCase() != dayName.toLowerCase()) {
          //   print('    ❌ Day mismatch: $scheduleDay != $dayName');
          //   continue;
          // }

          // Extract time info
          final String timeIn = item['timeIn'] ?? '';
          final String timeOut = item['timeOut'] ?? '';

          String timeStr = '';
          if (timeIn.isNotEmpty && timeOut.isNotEmpty) {
            String formattedTimeIn = timeIn.length >= 5
                ? timeIn.substring(0, 5)
                : timeIn;
            String formattedTimeOut = timeOut.length >= 5
                ? timeOut.substring(0, 5)
                : timeOut;

            try {
              final inParts = formattedTimeIn.split(':');
              final outParts = formattedTimeOut.split(':');

              if (inParts.length >= 2 && outParts.length >= 2) {
                final inTime = TimeOfDay(
                  hour: int.parse(inParts[0]),
                  minute: int.parse(inParts[1]),
                );
                final outTime = TimeOfDay(
                  hour: int.parse(outParts[0]),
                  minute: int.parse(outParts[1]),
                );

                final inPeriod = inTime.hour >= 12 ? 'PM' : 'AM';
                final inHour = inTime.hour > 12
                    ? inTime.hour - 12
                    : (inTime.hour == 0 ? 12 : inTime.hour);
                final inMinute = inTime.minute.toString().padLeft(2, '0');

                final outPeriod = outTime.hour >= 12 ? 'PM' : 'AM';
                final outHour = outTime.hour > 12
                    ? outTime.hour - 12
                    : (outTime.hour == 0 ? 12 : outTime.hour);
                final outMinute = outTime.minute.toString().padLeft(2, '0');

                timeStr =
                    '$inHour:$inMinute $inPeriod - $outHour:$outMinute $outPeriod';
              }
            } catch (e) {
              timeStr = '$formattedTimeIn - $formattedTimeOut';
            }
          }

          loadedSchedules.add({
            'id': item['id'],
            'name': item['subject']?['name'] ?? 'Unknown Subject',
            'code': item['subject']?['code'] ?? 'N/A',
            'time': timeStr,
            'day': scheduleDay,
            'room': item['classroom']?['name'] ?? 'Unknown Room',
            'section': item['section']?['name'] ?? 'Unknown Section',
            'instructor':
                '${item['instructor']?['firstname'] ?? ''} ${item['instructor']?['lastname'] ?? ''}'
                    .trim(),
            // Keep original data for session creation
            'original_data': item,
          });
        }

        setState(() {
          _schedules = loadedSchedules;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to load schedules';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    if (isToday) {
      return 'Today, ${DateFormat('MMM d').format(now)}';
    } else {
      return DateFormat('MMM d, yyyy').format(_selectedDate);
    }
  }

  void _showCalendarPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _selectedDate,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                  });
                  Navigator.pop(context);
                  _loadSchedules(); // Reload schedules for new date
                },
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  defaultTextStyle: const TextStyle(color: Colors.white),
                  weekendTextStyle: const TextStyle(color: Colors.white),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.white70),
                  weekendStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [
                    const Color(0xFF1E3A8A),
                    const Color(0xFF3B82F6),
                    const Color(0xFF60A5FA),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
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
                        _buildDateSelector(),
                        const SizedBox(height: 24),
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        _buildSchedulesList(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Image.asset(
            'lib/images/aclc_logo.png',
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Create Session',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF1E3A8A),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Session Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getFormattedDate(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_calendar_rounded),
            color: const Color(0xFF1E3A8A),
            onPressed: _showCalendarPicker,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search schedules...',
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSchedulesList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
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
      );
    }

    if (_schedules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No schedules found for this date',
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Schedules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ..._schedules.map((schedule) => _buildScheduleCard(schedule)).toList(),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final isSelected = _selectedSchedule == schedule['code'];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSchedule = schedule['code'];
        });
        _showSessionDetails(schedule);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Color(0xFF1E3A8A),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${schedule['code']} - ${schedule['name']}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        schedule['time'],
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        schedule['room'],
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        schedule['day'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (schedule['section'] != null &&
                          schedule['section'].isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule['section'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(
          schedule: schedule,
          selectedDate: _selectedDate,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
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
        selectedItemColor: isDark ? Colors.white : const Color(0xFF1E3A8A),
        unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: 2,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 24,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } else if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AttendanceScreen()),
            );
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
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Sections'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Session Details Screen
class SessionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final DateTime selectedDate;

  const SessionDetailsScreen({
    super.key,
    required this.schedule,
    required this.selectedDate,
  });

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  String _selectedRoom = 'Room 301 (Scheduled)';
  String? _sessionId;
  DateTime? _sessionStartTime;
  TimeOfDay? _cutoffTime;
  // final Uuid _uuid = const Uuid(); // Removed unused field
  bool _isSessionActive = false;

  final List<String> _rooms = [
    'Room 301 (Scheduled)',
    'Room 302',
    'Short Course Laboratory',
  ];

  Future<void> _selectCutoffTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1E3A8A)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _cutoffTime) {
      setState(() {
        _cutoffTime = picked;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Restore session state if active
    if (SessionState.instance.isActive) {
      _isSessionActive = true;
      _sessionStartTime = SessionState.instance.startTime;
      _cutoffTime = SessionState.instance.cutoffTime != null
          ? TimeOfDay.fromDateTime(SessionState.instance.cutoffTime!)
          : null;
    } else {
      _checkExistingSession();
    }
  }

  bool _isCheckingSession = false;

  Future<void> _checkExistingSession() async {
    setState(() {
      _isCheckingSession = true;
    });

    try {
      final scheduleId = widget.schedule['id'];
      final result = await ApiService().getSessionByScheduleId(scheduleId);

      if (result['success'] == true) {
        final List<dynamic> sessions = result['data'];
        if (sessions.isNotEmpty) {
          // Find active session or session for today
          // Sort by createdAt desc to get latest
          sessions.sort((a, b) {
            final dateA = DateTime.parse(a['createdAt']);
            final dateB = DateTime.parse(b['createdAt']);
            return dateB.compareTo(dateA);
          });

          final latestSession = sessions.first;
          final sessionDate = DateTime.parse(latestSession['sessionDate']);

          // Check if session is for the selected date
          final isSameDate =
              sessionDate.year == widget.selectedDate.year &&
              sessionDate.month == widget.selectedDate.month &&
              sessionDate.day == widget.selectedDate.day;

          if (isSameDate) {
            // Check if session is active (no end time)
            // The user provided example shows actualEndTime as null for active/new sessions
            final isActive = latestSession['actualEndTime'] == null;

            if (isActive) {
              setState(() {
                _isSessionActive = true;
                _sessionId =
                    latestSession['uniqueHash'] ??
                    latestSession['id']
                        .toString(); // Use uniqueHash if available, else ID

                // Parse start time if available, else use sessionDate
                if (latestSession['actualStartTime'] != null) {
                  _sessionStartTime = DateTime.parse(
                    latestSession['actualStartTime'],
                  );
                } else {
                  _sessionStartTime = sessionDate;
                }

                // Restore cutoff if available
                if (latestSession['attendanceCutOff'] != null) {
                  final cutoff = DateTime.parse(
                    latestSession['attendanceCutOff'],
                  );
                  _cutoffTime = TimeOfDay.fromDateTime(cutoff);
                }
              });

              // Update global state
              SessionState.instance.startSession(
                widget.schedule,
                _sessionStartTime!,
                hash: _sessionId,
              );

              if (_cutoffTime != null) {
                final now = DateTime.now();
                SessionState.instance.cutoffTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  _cutoffTime!.hour,
                  _cutoffTime!.minute,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking existing session: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  bool _isStartingSession = false;

  Future<void> _startSession() async {
    setState(() {
      _isStartingSession = true;
    });

    try {
      // 1. Show Configuration Dialog
      final config = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const QrGenerationDialog(),
      );

      if (config == null) {
        setState(() => _isStartingSession = false);
        return; // User cancelled
      }

      final int expirationMinutes = config['expirationMinutes'];
      final int? maxUsage = config['maxUsage'];
      final String uniqueHash = config['uniqueHash'];

      // 2. Create Session
      final sessionResult = await ApiService().createSession(
        scheduleId: widget.schedule['id'],
      );

      if (sessionResult['success'] != true) {
        throw Exception(sessionResult['error'] ?? 'Failed to create session');
      }

      final sessionData = sessionResult['data'];
      final sessionId = sessionData['id'];

      // Calculate attendance cutoff based on expiration if not manually set
      // Or use the manual cutoff if set
      int? attendanceCutoffMinutes;
      if (_cutoffTime != null) {
        // ... existing cutoff logic if needed, or rely on expiration
        // For now, let's respect the dialog's expiration for the QR code validity
        // and the manual cutoff for the session attendance window if set.
        final now = DateTime.now();
        final cutoff = DateTime(
          now.year,
          now.month,
          now.day,
          _cutoffTime!.hour,
          _cutoffTime!.minute,
        );
        final diff = cutoff.difference(now).inMinutes;
        if (diff > 0) attendanceCutoffMinutes = diff;
      } else {
        // If no manual cutoff, maybe use expiration time?
        // The user prompt implies expiration is for the QR code.
        // Let's stick to existing logic: if _cutoffTime is null, attendanceCutoffMinutes is null (unlimited/manual stop)
      }

      // 3. Start Session
      final startResult = await ApiService().startSession(
        sessionId,
        actualRoomId: null,
        attendanceCutoffMinutes: attendanceCutoffMinutes,
      );

      if (startResult['success'] != true) {
        throw Exception(startResult['error'] ?? 'Failed to start session');
      }

      // 4. Generate QR Code
      final result = await ApiService().generateQrCode(
        sessionId: sessionId,
        expirationMinutes: expirationMinutes,
        uniqueHash: uniqueHash,
        maxUsage: maxUsage,
      );

      if (result['success'] == true) {
        // ... success handling ...
        setState(() {
          _isSessionActive = true;
          _sessionStartTime = DateTime.now();
          _sessionId = uniqueHash;
        });

        SessionState.instance.startSession(
          widget.schedule,
          _sessionStartTime!,
          hash: uniqueHash,
        );

        if (_cutoffTime != null) {
          // ... update cutoff in state ...
          final now = DateTime.now();
          SessionState.instance.cutoffTime = DateTime(
            now.year,
            now.month,
            now.day,
            _cutoffTime!.hour,
            _cutoffTime!.minute,
          );
        }

        _showQrCode();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to generate QR code'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      final errorMessage = e.toString();
      if (errorMessage.contains('already exists')) {
        if (mounted) {
          _showSessionConflictDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingSession = false;
        });
      }
    }
  }

  void _showSessionConflictDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Conflict'),
        content: const Text(
          'A session already exists for this schedule today. Do you want to delete the existing session and start a new one?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAndRetrySession();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete & Start New'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAndRetrySession() async {
    setState(() => _isStartingSession = true);
    try {
      final scheduleId = widget.schedule['id'];
      final result = await ApiService().getSessionByScheduleId(scheduleId);

      if (result['success'] == true) {
        final List<dynamic> sessions = result['data'];
        final now = DateTime.now();
        final todaySession = sessions.firstWhere((s) {
          final date = DateTime.parse(s['sessionDate']);
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }, orElse: () => null);

        if (todaySession != null) {
          final deleteResult = await ApiService().deleteSession(
            todaySession['id'],
          );
          if (deleteResult['success'] == true) {
            if (mounted) {
              // Reset state and retry
              setState(() {
                _isStartingSession = false;
              });
              _startSession();
            }
          } else {
            throw Exception(
              deleteResult['error'] ?? 'Failed to delete session',
            );
          }
        } else {
          throw Exception('Could not find the conflicting session to delete.');
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to fetch sessions');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStartingSession = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQrCode() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(width: double.infinity),
                  const Text(
                    'QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _generateQrData(),
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${widget.schedule['code']} - ${widget.schedule['name']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildQrDetailRow(Icons.location_on, _selectedRoom),
                    const SizedBox(height: 8),
                    _buildQrDetailRow(
                      Icons.access_time,
                      widget.schedule['time'],
                    ),
                    const SizedBox(height: 8),
                    _buildQrDetailRow(
                      Icons.person,
                      (widget.schedule['instructor']?.toString().isNotEmpty ==
                              true)
                          ? widget.schedule['instructor']
                          : 'Unknown Instructor',
                    ),
                    if (_sessionStartTime != null) ...[
                      const SizedBox(height: 8),
                      _buildQrDetailRow(
                        Icons.timer_outlined,
                        'Started: ${_formatTime(_sessionStartTime!)}',
                      ),
                    ],
                    if (_cutoffTime != null) ...[
                      const SizedBox(height: 8),
                      _buildQrDetailRow(
                        Icons.timer_off_outlined,
                        'Cut-off: ${_cutoffTime!.format(context)}',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _generateQrData() {
    // Return the hash from session state or local state
    // This hash is what the student app will scan
    return SessionState.instance.qrHash ?? _sessionId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Session Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionInfo(),
            const SizedBox(height: 20),
            _buildRoomSelector(),
            const SizedBox(height: 20),
            _buildCutoffSelector(),
            const SizedBox(height: 20),
            if (_isSessionActive) _buildActiveSession(),
          ],
        ),
      ),
      bottomNavigationBar: !_isSessionActive
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(child: _buildStartButton()),
            )
          : null,
    );
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.schedule['name'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.schedule['code'],
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.access_time, widget.schedule['time']),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, widget.schedule['room']),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.person,
            (widget.schedule['instructor']?.toString().isNotEmpty == true)
                ? widget.schedule['instructor']
                : 'Unknown Instructor',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildRoomSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actual Room (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedRoom,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: _rooms.map((room) {
              return DropdownMenuItem(value: room, child: Text(room));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoom = value!;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCutoffSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Cut-off (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _selectCutoffTime(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _cutoffTime != null
                        ? _cutoffTime!.format(context)
                        : 'Select cut-off time',
                    style: TextStyle(
                      color: _cutoffTime != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isStartingSession || _isCheckingSession)
            ? null
            : _startSession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A8A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: (_isStartingSession || _isCheckingSession)
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Start Session',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActiveSession() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Active',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    if (_sessionStartTime != null)
                      Text(
                        'Started at ${_formatTime(_sessionStartTime!)}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showQrCode,
              icon: const Icon(Icons.qr_code, color: Colors.white),
              label: const Text(
                'Show QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isSessionActive = false;
                  _sessionId = null;
                  _sessionStartTime = null;
                  _cutoffTime = null;
                });
                SessionState.instance.endSession();
              },
              icon: Icon(
                Icons.stop_circle_outlined,
                color: Colors.red.shade600,
              ),
              label: Text(
                'End Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QrGenerationDialog extends StatefulWidget {
  const QrGenerationDialog({super.key});

  @override
  State<QrGenerationDialog> createState() => _QrGenerationDialogState();
}

class _QrGenerationDialogState extends State<QrGenerationDialog> {
  int _expirationMinutes = 30;
  final TextEditingController _maxUsageController = TextEditingController();
  final TextEditingController _hashController = TextEditingController();
  bool _isUnlimitedUsage = true;

  @override
  void initState() {
    super.initState();
    _generateNewHash();
  }

  void _generateNewHash() {
    setState(() {
      _hashController.text = const Uuid().v4();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 12),
                    Text(
                      'Generate QR Code',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a QR code for students to scan. They can use their mobile app to record attendance.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Expiration Time
            _buildLabel('Expiration Time', isRequired: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _expirationMinutes,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: [15, 30, 60, 120].map((minutes) {
                    return DropdownMenuItem(
                      value: minutes,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$minutes Minutes${minutes == 30 ? " (Default)" : ""}',
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _expirationMinutes = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How long the QR code remains valid.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Max Usage Limit
            _buildLabel('Max Usage Limit', isRequired: false),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.numbers,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _maxUsageController,
                      enabled: !_isUnlimitedUsage,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter limit',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_isUnlimitedUsage)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        'Unlimited',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isUnlimitedUsage = !_isUnlimitedUsage;
                  if (_isUnlimitedUsage) _maxUsageController.clear();
                });
              },
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isUnlimitedUsage,
                      onChanged: (value) {
                        setState(() {
                          _isUnlimitedUsage = value ?? true;
                          if (_isUnlimitedUsage) _maxUsageController.clear();
                        });
                      },
                      activeColor: const Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Unlimited usage'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Unique Identifier Hash
            _buildLabel('Unique Identifier Hash', isRequired: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tag, size: 18, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hashController.text,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _generateNewHash,
                    tooltip: 'Generate new hash',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Client-side signature identifier for this QR code.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 32),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final maxUsage = _isUnlimitedUsage
                          ? null
                          : int.tryParse(_maxUsageController.text);

                      Navigator.pop(context, {
                        'expirationMinutes': _expirationMinutes,
                        'maxUsage': maxUsage,
                        'uniqueHash': _hashController.text,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Generate QR Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        if (!isRequired)
          Text(
            ' (Optional)',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
      ],
    );
  }
}
