import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';
import 'qr_screen.dart';
import 'sections_screen.dart';
import '../services/api_service.dart';

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

    final result = await _apiService.getInstructorSections();

    if (result['success']) {
      // Extract all schedules from grouped sections
      List<Map<String, dynamic>> allSchedules = [];
      final groupedSections = result['data'] as Map<String, dynamic>;
      
      _groupedSections = groupedSections;
      
      // Calculate stats
      _totalSections = groupedSections.keys.length;
      _totalSubjects = 0;
      
      for (var subjects in groupedSections.values) {
        final subjectList = List<Map<String, dynamic>>.from(subjects);
        _totalSubjects += subjectList.length;
        allSchedules.addAll(subjectList);
      }
      
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
        
        final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
        final endDateTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);
        
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
    parsedSchedules.sort((a, b) => 
      (a['startDateTime'] as DateTime).compareTo(b['startDateTime'] as DateTime)
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
    if (foundCurrentClass == null && foundNextClass == null && parsedSchedules.isNotEmpty) {
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
    // Parse "HH:MM" format
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    throw FormatException('Invalid time format: $timeStr');
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final now = DateTime.now();
        
        // Update current class countdown
        if (currentClassEnd != null && now.isBefore(currentClassEnd!)) {
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

  String _formatScheduleTime(String? schedule) {
    if (schedule == null || schedule.isEmpty) return '';
    
    // Extract time from "Monday 08:00-10:00" format
    final parts = schedule.split(' ');
    if (parts.length < 2) return '';
    
    final timeRange = parts[1]; // "08:00-10:00"
    final times = timeRange.split('-');
    if (times.isEmpty) return '';
    
    // Return start time (e.g., "08:00 AM")
    try {
      final time = _parseTime(times[0]);
      final hour = time.hour;
      final minute = time.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return times[0]; // Return as is if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Deep blue
              Color(0xFF3B82F6), // Blue
              Color(0xFF60A5FA), // Light blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // ACLC Logo
                    Image.asset(
                'lib/images/aclc_logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    // Teacher Dashboard Title
                    Expanded(
                      child: Text(
                        'Teacher Dashboard',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    // Notification Bell
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overview Section
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Overview Cards Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3, // Increased from 1.5 to give more vertical space
                          children: [
                            _buildOverviewCard(
                              'Sections',
                              _isLoading ? '...' : '$_totalSections',
                              Icons.school,
                              const Color(0xFF3B82F6),
                            ),
                            _buildOverviewCard(
                              'Subjects',
                              _isLoading ? '...' : '$_totalSubjects',
                              Icons.book,
                              const Color(0xFF10B981),
                            ),
                            _buildOverviewCard(
                              'Students',
                              _isLoading ? '...' : '$_totalStudents',
                              Icons.people,
                              const Color(0xFF8B5CF6),
                            ),
                            _buildOverviewCard(
                              'Classes',
                              _isLoading ? '...' : '${_totalSubjects > 0 ? _totalSubjects : "0"}',
                              Icons.class_,
                              const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Loading or Error State
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                              ),
                            ),
                          )
                        else if (_errorMessage != null)
                          Center(
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
                          )
                        else ...[
                          // Current Class Section
                          Text(
                            'Current Class',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
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
                              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                              _formatDuration(currentClassTimeLeft),
                              true, // is current class
                            )
                          else
                            _buildNoClassCard('No ongoing class at the moment'),
                          
                          const SizedBox(height: 16),
                          
                          // Next Class Section
                          Text(
                            'Next Class',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
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
                              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                              _formatDuration(nextClassTimeLeft),
                              false, // is next class
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1E3A8A),
          unselectedItemColor: Colors.grey,
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const QrScreen(),
                ),
              );
            } else if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SectionsScreen(),
                ),
              );
            } else if (index == 4) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code),
              label: 'QR',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: 'Sections',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14), // Reduced from 16 to 14
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
        mainAxisSize: MainAxisSize.min, // Prevent overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space evenly
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 18, // Reduced from 20 to 18
            ),
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
                    fontSize: 20, // Reduced from 22 to 20
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
                fontSize: 11, // Reduced from 12 to 11
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
    bool isCurrent
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrent 
            ? [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)]
            : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: (isCurrent ? const Color(0xFF1E3A8A) : const Color(0xFF3B82F6)).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? 'Current Class' : 'Next Class',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  course,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              countdown,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF93C5FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF60A5FA).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}