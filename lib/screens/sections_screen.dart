import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'attendance_screen.dart';
import 'qr_screen.dart';
import 'profile_screen.dart';
import 'students_screen.dart';

class SectionsScreen extends StatefulWidget {
  const SectionsScreen({super.key});

  @override
  State<SectionsScreen> createState() => _SectionsScreenState();
}

class _SectionsScreenState extends State<SectionsScreen> {
  final ApiService _apiService = ApiService();
  Map<String, List<Map<String, dynamic>>> _groupedSections = {};
  Map<String, bool> _expandedPrograms = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getInstructorSections();

    if (result['success']) {
      setState(() {
        _groupedSections = Map<String, List<Map<String, dynamic>>>.from(
          result['data'].map((key, value) => MapEntry(
            key,
            List<Map<String, dynamic>>.from(value),
          )),
        );
        // Initialize all programs as collapsed
        _expandedPrograms = {
          for (var program in _groupedSections.keys) program: false
        };
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to load sections';
        _isLoading = false;
      });
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
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsiveWidget(
            mobile: _buildMobileLayout(context),
            tablet: _buildTabletLayout(context),
            desktop: _buildDesktopLayout(context),
          ),
        ),
      ),
      bottomNavigationBar: _buildResponsiveBottomNav(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Row(
            children: [
              Image.asset(
                'lib/images/aclc_logo.png',
                width: ResponsiveUtils.getResponsiveImageSize(context, mobile: 40, tablet: 50, desktop: 60),
                height: ResponsiveUtils.getResponsiveImageSize(context, mobile: 40, tablet: 50, desktop: 60),
                fit: BoxFit.contain,
              ),
              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
              Expanded(
                child: Text(
                  'My Classes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 20, tablet: 24, desktop: 28),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24, tablet: 28, desktop: 32),
                ),
                onPressed: _loadSections,
              ),
            ],
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
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Left sidebar
        Container(
          width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 0, tablet: 200, desktop: 250),
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A8A),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  children: [
                    Image.asset(
                      'lib/images/aclc_logo.png',
                      width: ResponsiveUtils.getResponsiveImageSize(context, mobile: 40, tablet: 50, desktop: 60),
                      height: ResponsiveUtils.getResponsiveImageSize(context, mobile: 40, tablet: 50, desktop: 60),
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
                    Text(
                      'My Classes',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildSidebarNavigation(context)),
            ],
          ),
        ),
        // Main content
        Expanded(
          child: Container(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return _buildTabletLayout(context);
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
              'Error loading sections',
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
              onPressed: _loadSections,
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

    if (_groupedSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sections found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no assigned sections yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSections,
      child: SingleChildScrollView(
        padding: ResponsiveUtils.getResponsivePadding(context),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _groupedSections.entries.map((entry) {
            final programName = entry.key;
            final sections = entry.value;
            final isExpanded = _expandedPrograms[programName] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Program Header (Course Name: BSBA31C, BSCS31A, etc.)
                  ListTile(
                    title: Text(
                      programName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 18,
                              tablet: 20,
                              desktop: 24,
                            ),
                          ),
                    ),
                    subtitle: Text(
                      '${sections.length} ${sections.length == 1 ? 'subject' : 'subjects'}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF1E3A8A),
                      size: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                        tablet: 24,
                        desktop: 28,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _expandedPrograms[programName] = !isExpanded;
                      });
                    },
                  ),

                  // Subjects List
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12),
                      ),
                      child: Column(
                        children: sections.map((section) => _buildSectionCard(context, section)).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, Map<String, dynamic> section) {
    // Get icon and color based on subject name
    final iconData = _getSubjectIcon(section['name']);
    final color = _getSubjectColor(section['name']);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
        vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32, tablet: 40, desktop: 48),
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32, tablet: 40, desktop: 48),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            iconData,
            color: color,
            size: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
          ),
        ),
        title: Text(
          section['name'], // Just the subject name (e.g., "Programming Language")
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E3A8A),
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: const Color(0xFF1E3A8A),
          size: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StudentsScreen(
                sectionId: section['sectionId'],
                subjectName: section['name'], // Just subject name
                subjectCode: section['code'],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getSubjectIcon(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('programming') || name.contains('code')) return Icons.code;
    if (name.contains('data') || name.contains('structure')) return Icons.storage;
    if (name.contains('math')) return Icons.calculate;
    if (name.contains('computing') || name.contains('computer')) return Icons.computer;
    if (name.contains('self') || name.contains('psychology')) return Icons.psychology;
    if (name.contains('network')) return Icons.lan;
    if (name.contains('database')) return Icons.dns;
    if (name.contains('web')) return Icons.web;
    return Icons.book;
  }

  Color _getSubjectColor(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('programming') || name.contains('code')) return Colors.blue;
    if (name.contains('data') || name.contains('structure')) return Colors.purple;
    if (name.contains('math')) return Colors.orange;
    if (name.contains('computing') || name.contains('computer')) return Colors.red;
    if (name.contains('self') || name.contains('psychology')) return Colors.green;
    if (name.contains('network')) return Colors.teal;
    if (name.contains('database')) return Colors.indigo;
    if (name.contains('web')) return Colors.pink;
    return Colors.grey;
  }

  Widget _buildSidebarNavigation(BuildContext context) {
    return Column(
      children: [
        _buildSidebarItem(context, Icons.home, 'Home', 0),
        _buildSidebarItem(context, Icons.assignment, 'Attendance', 1),
        _buildSidebarItem(context, Icons.qr_code, 'QR', 2),
        _buildSidebarItem(context, Icons.groups, 'Sections', 3),
        _buildSidebarItem(context, Icons.person, 'Profile', 4),
      ],
    );
  }

  Widget _buildSidebarItem(BuildContext context, IconData icon, String label, int index) {
    final isSelected = index == 3;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16),
        vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8),
      ),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
          size: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _handleNavigation(context, index),
      ),
    );
  }

  Widget _buildResponsiveBottomNav(BuildContext context) {
    if (ResponsiveUtils.isMobile(context)) {
      return Container(
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
          currentIndex: 3,
          onTap: (index) => _handleNavigation(context, index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'QR'),
            BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Sections'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const DashboardScreen()));
        break;
      case 1:
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AttendanceScreen()));
        break;
      case 2:
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => QrScreen()));
        break;
      case 3:
        // Already on sections
        break;
      case 4:
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProfileScreen()));
        break;
    }
  }
}