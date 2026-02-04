# 📱 Attendance Management System - Teacher Mobile App

## ✨ Features

### 🏠 Dashboard
- **Real-time Statistics**: View total sections, subjects, students, and classes at a glance
- **Current Class Tracking**: See ongoing class with live countdown timer
- **Next Class Preview**: Check upcoming class schedule
- **Live Schedule Updates**: Automatic refresh with real-time data

### 👥 Attendance Management
- **Quick Status Overview**: View present, late, and absent counts
- **Student List**: Comprehensive attendance list with filtering options
- **Status Filtering**: Filter students by present, late, absent, or view all
- **Time Tracking**: See exact check-in times for each student

### 📱 QR Code Scanning
- **Quick Attendance**: Scan student QR codes for instant attendance marking
- **Session Management**: Start and end attendance sessions easily
- **Real-time Updates**: Instant attendance status updates

### 📚 Sections & Subjects
- **Section Management**: View all your assigned sections
- **Subject Details**: Access subject codes, schedules, and classrooms
- **Student Lists**: See all students enrolled in each section

### 👤 Profile Management
- **Personal Information**: View and edit your profile details
- **Account Settings**: Update firstname, lastname, and email
- **Logout**: Secure logout with backend session management

## 🎨 Design Features

- **Navy Blue Theme**: Professional and modern UI design
- **Gradient Backgrounds**: Beautiful gradient effects throughout
- **Smooth Animations**: Fluid transitions and interactions
- **Responsive Layout**: Optimized for all mobile screen sizes
- **Material Design**: Following Flutter's Material Design guidelines

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: Version 3.0.0 or higher
- **Dart SDK**: Version 2.17.0 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Git**: For version control

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/attendance-management-teacher-new.git
   cd attendance-management-teacher-new/ams-teacher-mobile
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoint**
   
   Open `lib/config/api_constants.dart` and update the base URL:
   ```dart
   static const String baseUrl = 'http://your-backend-url:8081';
   ```

4. **Run the application**
   ```bash
   # For development
   flutter run

   # For release build
   flutter build apk --release
   ```

## 🔧 Configuration

### Backend API Setup

The app connects to a .NET backend API. Make sure your backend is running and accessible.

**Required Endpoints:**
- `POST /api/account/login` - User authentication
- `POST /api/account/logout` - User logout
- `GET /api/instructors/{id}` - Get instructor profile
- `PATCH /api/instructors/{id}` - Update instructor profile
- `GET /api/schedules` - Get instructor schedules
- `GET /api/sections/{id}/all-students` - Get section students

### API Configuration File

Location: `lib/config/api_constants.dart`

```dart
class ApiConstants {
  static const String baseUrl = 'http://localhost:8081';
  static const Duration connectionTimeout = Duration(seconds: 30);
  
  // Endpoints
  static const String loginEndpoint = '/api/account/login';
  static const String logoutEndpoint = '/api/account/logout';
  static const String instructorProfileEndpoint = '/api/instructors';
  static const String schedulesEndpoint = '/api/schedules';
}
```

## 📂 Project Structure

```
ams-teacher-mobile/
├── lib/
│   ├── config/
│   │   └── api_constants.dart          # API configuration
│   ├── models/
│   │   └── instructor_profile_model.dart # Data models
│   ├── screens/
│   │   ├── attendance_screen.dart       # Attendance management
│   │   ├── dashboard_screen.dart        # Main dashboard
│   │   ├── login_screen.dart            # Authentication
│   │   ├── profile_screen.dart          # User profile
│   │   ├── qr_screen.dart               # QR code scanning
│   │   └── sections_screen.dart         # Sections & subjects
│   ├── services/
│   │   ├── api_service.dart             # API integration
│   │   └── storage_service.dart         # Local storage
│   ├── utils/
│   │   └── responsive_utils.dart        # Responsive helpers
│   └── main.dart                         # App entry point
├── assets/
│   └── images/
│       └── aclc_logo.png                 # App logo
└── pubspec.yaml                          # Dependencies
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0                    # HTTP requests
  shared_preferences: ^2.2.2      # Local storage
  intl: ^0.18.1                   # Date formatting
  qr_code_scanner: ^1.0.1         # QR scanning
  permission_handler: ^11.0.1     # Permissions
```

## 🔐 Authentication Flow

1. User enters username and password
2. App sends credentials to `/api/account/login`
3. Backend returns JWT token and instructor ID
4. Token stored in shared preferences
5. Token used for all subsequent API requests
6. Logout clears token and session

## 📱 Screens Overview

### Login Screen
- Modern glassmorphism design
- Form validation
- Error handling
- JWT token authentication

### Dashboard Screen
- Overview cards (sections, subjects, students, classes)
- Current class card with countdown
- Next class preview
- Bottom navigation

### Attendance Screen
- Status cards (present, late, absent)
- Filterable student list
- Interactive filter modal
- Real-time status updates

### QR Screen
- Camera permission handling
- QR code scanner
- Attendance session management
- Student verification

### Sections Screen
- Grouped by section name
- Expandable subject lists
- Student count per section
- Schedule information

### Profile Screen
- Profile card with avatar
- Editable information (firstname, lastname, email)
- Created/updated timestamps
- Logout functionality

## 🛠️ Development

### Running in Debug Mode

```bash
flutter run --debug
```

### Building for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## 🐛 Troubleshooting

### Common Issues

1. **"Connection timeout" error**
   - Check if backend is running
   - Verify API URL in `api_constants.dart`
   - Check network connection

2. **"Session expired" error**
   - Token has expired, re-login required
   - Check token expiration in backend

3. **QR Scanner not working**
   - Grant camera permissions
   - Check `AndroidManifest.xml` permissions
   - Verify QR code format

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Contributors

- **Teacher Module Development Team**
- Backend API Team
- UI/UX Design Team

## 🔄 Version History

### v1.0.0 (Current)
- ✅ Initial release
- ✅ Authentication system
- ✅ Dashboard with real-time data
- ✅ Attendance management
- ✅ QR code scanning
- ✅ Profile management
- ✅ Sections & subjects view
- ✅ Navy blue theme implementation

---

