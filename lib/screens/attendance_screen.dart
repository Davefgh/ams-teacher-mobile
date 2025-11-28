import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'qr_screen.dart';
import 'sections_screen.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int? sessionId; // Optional session ID passed from other screens

  const AttendanceScreen({super.key, this.sessionId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiService _apiService = ApiService();
  String selectedSort = 'all'; // Default: show all students
  bool isLoading = false;
  bool isLoadingSessions = false;
  String? errorMessage;

  // Session and attendance data
  int? _selectedSessionId;
  Map<String, dynamic>? _sessionData;
  List<Map<String, dynamic>> _attendanceRecords = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _selectedSessionId = widget.sessionId;
    _loadSessions();
    if (_selectedSessionId != null) {
      _loadAttendanceData();
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      isLoadingSessions = true;
      errorMessage = null;
    });

    try {
      final instructorId = await StorageService.getInstructorId();
      if (instructorId == null) {
        setState(() {
          errorMessage = 'Instructor ID not found';
          isLoadingSessions = false;
        });
        return;
      }

      final sessionsResult = await _apiService.getSessions();
      final subjectsResult = await _apiService.getInstructorSubjects(
        instructorId,
      );

      if (sessionsResult['success'] == true &&
          subjectsResult['success'] == true) {
        final List<dynamic> sessionsData = sessionsResult['data'];
        final List<dynamic> subjectsData = subjectsResult['data'];

        // Create a set of valid subject names for filtering
        // Note: Sessions might not have subjectId directly, so we might need to match by name
        // or ensure the session object has subject info.
        // Based on previous code, session has 'subjectName'.
        final validSubjectNames = subjectsData
            .map((s) => s['name'].toString().toLowerCase())
            .toSet();

        if (sessionsData.isNotEmpty) {
          final List<Map<String, dynamic>> allSessions =
              List<Map<String, dynamic>>.from(sessionsData);

          // Filter sessions
          final filteredSessions = allSessions.where((session) {
            final subjectName = session['subjectName']
                ?.toString()
                .toLowerCase();
            final scheduleTitle = session['scheduleTitle']
                ?.toString()
                .toLowerCase();

            // Check if subject name or schedule title matches any valid subject
            if (subjectName != null &&
                validSubjectNames.contains(subjectName)) {
              return true;
            }
            if (scheduleTitle != null &&
                validSubjectNames.contains(scheduleTitle)) {
              return true;
            }
            return false;
          }).toList();

          setState(() {
            _sessions = filteredSessions;
            if (_sessions.isNotEmpty && _selectedSessionId == null) {
              // Select first session if none selected
              _selectedSessionId = _sessions[0]['id'];
              _loadAttendanceData();
            }
          });
        }
      } else {
        setState(() {
          errorMessage =
              sessionsResult['error'] ??
              subjectsResult['error'] ??
              'Failed to load data';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading sessions: $e';
      });
    } finally {
      setState(() {
        isLoadingSessions = false;
      });
    }
  }

  Future<void> _loadAttendanceData() async {
    if (_selectedSessionId == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Load attendance by session
      final attendanceResult = await _apiService.getAttendanceBySession(
        _selectedSessionId!,
      );

      if (attendanceResult['success'] == true) {
        final data = attendanceResult['data'];
        setState(() {
          _sessionData = data;
          _attendanceRecords = List<Map<String, dynamic>>.from(
            data['attendanceRecords'] ?? [],
          );
        });
      } else {
        setState(() {
          errorMessage =
              attendanceResult['error'] ?? 'Failed to load attendance';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading attendance: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateAttendanceStatus(
    int attendanceId,
    String newStatus,
  ) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await _apiService.updateAttendance(
        id: attendanceId,
        status: newStatus,
      );

      if (result['success'] == true) {
        // Reload attendance data
        await _loadAttendanceData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to update attendance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredAttendanceList {
    if (selectedSort == 'all') {
      return _attendanceRecords;
    } else {
      return _attendanceRecords.where((record) {
        final status = record['status']?.toString().toLowerCase() ?? '';
        return status == selectedSort.toLowerCase();
      }).toList();
    }
  }

  int get presentCount {
    return _attendanceRecords
        .where(
          (r) => (r['status']?.toString().toLowerCase() ?? '') == 'present',
        )
        .length;
  }

  int get absentCount {
    return _attendanceRecords
        .where((r) => (r['status']?.toString().toLowerCase() ?? '') == 'absent')
        .length;
  }

  int get lateCount {
    return _attendanceRecords
        .where((r) => (r['status']?.toString().toLowerCase() ?? '') == 'late')
        .length;
  }

  int get excusedCount {
    return _attendanceRecords
        .where(
          (r) => (r['status']?.toString().toLowerCase() ?? '') == 'excused',
        )
        .length;
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '--';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final hour = dateTime.hour;
      final minute = dateTime.minute;
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return '--';
    }
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '--';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${monthNames[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return '--';
    }
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
                    const Color(0xFF1E3A8A), // Deep blue
                    const Color(0xFF3B82F6), // Blue
                    const Color(0xFF60A5FA), // Light blue
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
                    // Attendance Title
                    const Expanded(
                      child: Text(
                        'Attendance',
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

              // Main Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: isLoadingSessions
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage != null && _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadSessions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _selectedSessionId == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No session selected',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please select a session to view attendance',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Session Selection
                              if (_sessions.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1E3A8A),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Session',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            DropdownButton<int>(
                                              value: _selectedSessionId,
                                              isExpanded: true,
                                              underline: const SizedBox(),
                                              dropdownColor: isDark
                                                  ? const Color(0xFF1E293B)
                                                  : Colors.white,
                                              iconEnabledColor: isDark
                                                  ? Colors.white
                                                  : Colors.grey[700],
                                              items: _sessions.map((session) {
                                                final sessionDate = _formatDate(
                                                  session['sessionDate']
                                                      ?.toString(),
                                                );
                                                final subjectName =
                                                    session['subjectName']
                                                        ?.toString() ??
                                                    session['scheduleTitle']
                                                        ?.toString() ??
                                                    'Unknown';
                                                return DropdownMenuItem<int>(
                                                  value: session['id'],
                                                  child: Text(
                                                    '$subjectName - $sessionDate',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedSessionId = value;
                                                });
                                                _loadAttendanceData();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Session Info
                              if (_sessionData != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _sessionData!['subjectName']
                                                ?.toString() ??
                                            _sessionData!['scheduleTitle']
                                                ?.toString() ??
                                            'Unknown Subject',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (_sessionData!['sectionName'] != null)
                                        Text(
                                          'Section: ${_sessionData!['sectionName']}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      if (_sessionData!['sessionDate'] !=
                                          null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${_formatDate(_sessionData!['sessionDate']?.toString())}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Status Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatusCard(
                                      'Present',
                                      presentCount.toString(),
                                      Icons.check_circle,
                                      const Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusCard(
                                      'Late',
                                      lateCount.toString(),
                                      Icons.schedule,
                                      const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatusCard(
                                      'Absent',
                                      absentCount.toString(),
                                      Icons.cancel,
                                      const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),

                              if (excusedCount > 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatusCard(
                                        'Excused',
                                        excusedCount.toString(),
                                        Icons.info,
                                        const Color(0xFF6366F1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(), // Empty space
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(), // Empty space
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Sort Section
                              Row(
                                children: [
                                  Text(
                                    'Attendance List',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E3A8A),
                                          fontSize: 20,
                                        ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: _showSortSheet,
                                    icon: Icon(
                                      Icons.sort,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E3A8A),
                                      size: 24,
                                    ),
                                    splashRadius: 22,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Loading indicator
                              if (isLoading && _attendanceRecords.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (errorMessage != null &&
                                  _attendanceRecords.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          errorMessage!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _loadAttendanceData,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (filteredAttendanceList.isEmpty)
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No attendance records found',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                // Attendance List
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredAttendanceList.length,
                                  itemBuilder: (context, index) {
                                    final record =
                                        filteredAttendanceList[index];
                                    return _buildStudentCard(record);
                                  },
                                ),
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
          selectedItemColor: isDark ? Colors.white : const Color(0xFF1E3A8A),
          unselectedItemColor: isDark ? Colors.grey[400] : Colors.grey,
          type: BottomNavigationBarType.fixed,
          currentIndex: 1, // Attendance tab selected
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 24,
          onTap: (index) {
            if (index == 0) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (context) => const QrScreen()));
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

  Widget _buildStatusCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.9), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                count,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> record) {
    final studentName = record['studentName']?.toString() ?? 'Unknown Student';
    final studentNumber =
        record['studentNumber']?.toString() ??
        record['studentId']?.toString() ??
        'N/A';
    final status = record['status']?.toString().toLowerCase() ?? '';
    final checkInTime = record['checkInTime']?.toString();
    final attendanceId = record['attendanceRecordId'] ?? record['id'];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFF1E3A8A).withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  studentNumber,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Time/Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (checkInTime != null)
                Text(
                  _formatDateTime(checkInTime),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                )
              else
                Text(
                  '--',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 6),
              // Status Badge with Tap to Change
              InkWell(
                onTap: attendanceId != null
                    ? () => _showStatusChangeDialog(
                        attendanceId,
                        status,
                        studentName,
                      )
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.isEmpty ? 'N/A' : status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (attendanceId != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: Colors.white, size: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatusChangeDialog(
    int attendanceId,
    String currentStatus,
    String studentName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Change Status',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: $studentName',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            _buildStatusOption(
              'Present',
              'present',
              Icons.check_circle,
              const Color(0xFF10B981),
              currentStatus,
              attendanceId,
            ),
            _buildStatusOption(
              'Late',
              'late',
              Icons.schedule,
              const Color(0xFFF59E0B),
              currentStatus,
              attendanceId,
            ),
            _buildStatusOption(
              'Absent',
              'absent',
              Icons.cancel,
              const Color(0xFFEF4444),
              currentStatus,
              attendanceId,
            ),
            _buildStatusOption(
              'Excused',
              'excused',
              Icons.info,
              const Color(0xFF6366F1),
              currentStatus,
              attendanceId,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    String label,
    String value,
    IconData icon,
    Color color,
    String currentStatus,
    int attendanceId,
  ) {
    final isSelected = currentStatus.toLowerCase() == value.toLowerCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _updateAttendanceStatus(attendanceId, value);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.1)
                  : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : Colors.grey[50]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.3)
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : Colors.grey.withOpacity(0.2)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? color
                          : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.grey[800]),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E293B)
          : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.filter_list,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Filter by Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                        fontSize: 20,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSheetOption(
                  'All Students',
                  'all',
                  Icons.people_alt,
                  const Color(0xFF3B82F6),
                ),
                _buildSheetOption(
                  'Present',
                  'present',
                  Icons.check_circle,
                  const Color(0xFF10B981),
                ),
                _buildSheetOption(
                  'Late',
                  'late',
                  Icons.schedule,
                  const Color(0xFFF59E0B),
                ),
                _buildSheetOption(
                  'Absent',
                  'absent',
                  Icons.cancel,
                  const Color(0xFFEF4444),
                ),
                _buildSheetOption(
                  'Excused',
                  'excused',
                  Icons.info,
                  const Color(0xFF6366F1),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetOption(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final bool active = selectedSort == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedSort = value;
            });
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.1) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? color.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                width: active ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active ? color.withOpacity(0.2) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: active ? color : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? color : Colors.grey[800],
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return const Color(0xFF10B981);
      case 'late':
        return const Color(0xFFF59E0B);
      case 'absent':
        return const Color(0xFFEF4444);
      case 'excused':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'late':
        return Icons.schedule;
      case 'absent':
        return Icons.cancel;
      case 'excused':
        return Icons.info;
      default:
        return Icons.help;
    }
  }
}
