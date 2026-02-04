import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'attendance_screen.dart';
import 'qr_screen.dart';
import 'sections_screen.dart';
import 'profile_screen.dart';

class StudentsScreen extends StatefulWidget {
  final int sectionId;
  final String subjectName;
  final String subjectCode;

  const StudentsScreen({
    super.key,
    required this.sectionId,
    required this.subjectName,
    required this.subjectCode,
  });

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getSectionStudents(widget.sectionId);

    if (result['success']) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(result['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to load students';
        _isLoading = false;
      });
    }
  }

  // Helper to get display name from student data
  String _getStudentDisplayName(Map<String, dynamic> student) {
    // Try to get full name from firstName, middleName, lastName
    final firstName = student['firstName']?.toString().trim() ?? '';
    final middleName = student['middleName']?.toString().trim() ?? '';
    final lastName = student['lastName']?.toString().trim() ?? '';

    // Build full name
    List<String> nameParts = [];
    if (firstName.isNotEmpty) nameParts.add(firstName);
    if (middleName.isNotEmpty) nameParts.add(middleName);
    if (lastName.isNotEmpty) nameParts.add(lastName);

    if (nameParts.isNotEmpty) {
      return nameParts.join(' ');
    }

    // Fallback to email username if name fields are empty
    final email = student['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) {
      // Extract username from email (before @)
      final username = email.split('@').first;
      return username;
    }

    // Final fallback to Student ID
    return 'Student ${student['studentId'] ?? 'Unknown'}';
  }

  List<Map<String, dynamic>> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;

    return _students.where((student) {
      final displayName = _getStudentDisplayName(student).toLowerCase();
      final studentId = student['studentId'].toString().toLowerCase();
      final email = student['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();

      return displayName.contains(query) ||
          studentId.contains(query) ||
          email.contains(query);
    }).toList();
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
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.subjectName,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 18,
                                        tablet: 20,
                                        desktop: 24,
                                      ),
                                ),
                          ),
                          Text(
                            widget.subjectCode,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                mobile: 14,
                                tablet: 16,
                                desktop: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 24,
                          tablet: 28,
                          desktop: 32,
                        ),
                      ),
                      onPressed: _loadStudents,
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF1E3A8A),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: _buildContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error loading students',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStudents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No students found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This section has no enrolled students yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final filteredStudents = _filteredStudents;

    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView.builder(
        padding: ResponsiveUtils.getResponsivePadding(context),
        itemCount: filteredStudents.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filteredStudents.length} ${filteredStudents.length == 1 ? 'Student' : 'Students'}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 18,
                        tablet: 20,
                        desktop: 22,
                      ),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Search'),
                    ),
                ],
              ),
            );
          }

          final student = filteredStudents[index - 1];
          return _buildStudentCard(context, student, index);
        },
      ),
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    Map<String, dynamic> student,
    int index,
  ) {
    final displayName = _getStudentDisplayName(student);
    final initials = _getInitials(displayName);

    // Check if we have actual name data
    final hasNameData =
        (student['firstName']?.toString().trim() ?? '').isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 16,
            tablet: 20,
            desktop: 24,
          ),
          vertical: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 8,
            tablet: 10,
            desktop: 12,
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(index),
          radius: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 20,
            tablet: 24,
            desktop: 28,
          ),
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 14,
                tablet: 16,
                desktop: 18,
              ),
            ),
          ),
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E3A8A),
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              mobile: 14,
              tablet: 16,
              desktop: 18,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Student ID: ${student['studentId']}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 12,
                  tablet: 14,
                  desktop: 16,
                ),
              ),
            ),
            if (student['email'] != null &&
                student['email'].toString().isNotEmpty)
              Text(
                student['email'],
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 11,
                    tablet: 13,
                    desktop: 15,
                  ),
                ),
              ),
            if (hasNameData && student['program'] != null)
              Text(
                '${student['program']} - Year ${student['yearLevel'] ?? 'N/A'}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 11,
                    tablet: 13,
                    desktop: 15,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: const Color(0xFF1E3A8A),
          size: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 20,
            tablet: 24,
            desktop: 28,
          ),
        ),
        onTap: () {
          _showStudentDetails(context, student);
        },
      ),
    );
  }

  String _getInitials(String displayName) {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || displayName.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color _getAvatarColor(int index) {
    final colors = [
      const Color(0xFF1E3A8A),
      const Color(0xFF3B82F6),
      const Color(0xFF60A5FA),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> student) {
    final displayName = _getStudentDisplayName(student);
    final hasNameData =
        (student['firstName']?.toString().trim() ?? '').isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Student Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 20),
              if (hasNameData)
                _buildDetailRow(Icons.person, 'Full Name', displayName)
              else
                _buildDetailRow(
                  Icons.person_outline,
                  'Display Name',
                  displayName,
                ),
              _buildDetailRow(
                Icons.badge,
                'Student ID',
                student['studentId']?.toString() ?? 'N/A',
              ),
              if (student['email'] != null &&
                  student['email'].toString().isNotEmpty)
                _buildDetailRow(Icons.email, 'Email', student['email']),
              if (hasNameData && student['program'] != null)
                _buildDetailRow(Icons.school, 'Program', student['program']),
              if (hasNameData && student['yearLevel'] != null)
                _buildDetailRow(
                  Icons.calendar_today,
                  'Year Level',
                  'Year ${student['yearLevel']}',
                ),
              if (!hasNameData)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Student profile incomplete',
                            style: TextStyle(
                              color: Colors.amber[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        currentIndex: 3, // Sections tab
        selectedFontSize: 12,
        unselectedFontSize: 12,
        iconSize: 24,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AttendanceScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const QrScreen()),
            );
          } else if (index == 3) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SectionsScreen()),
            );
          } else if (index == 4) {
            Navigator.of(context).pushReplacement(
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
