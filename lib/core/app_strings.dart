import 'app_locale.dart';

/// UI copy in both languages.
///
/// Deliberately a plain map rather than ARB/gen-l10n: the string count is small
/// and this keeps lookups usable from anywhere without a BuildContext.
class AppStrings {
  const AppStrings._();

  static String of(String key) {
    final table = _tables[LocaleController.instance.language] ?? _vi;
    return table[key] ?? _vi[key] ?? key;
  }

  static const Map<AppLanguage, Map<String, String>> _tables = {
    AppLanguage.vietnamese: _vi,
    AppLanguage.english: _en,
  };

  static const Map<String, String> _vi = {
    // Exercise explorer
    'exercises': 'Bài tập',
    'searchExercises': 'Tìm bài tập...',
    'exerciseCount': 'bài tập',
    'loading': 'Đang tải...',
    'noExercisesFound': 'Không tìm thấy bài tập nào',
    'retry': 'Thử lại',

    // Exercise detail
    'exerciseDetail': 'Chi tiết bài tập',
    'hasVideo': 'Có video hướng dẫn',
    'muscles': 'Nhóm cơ',
    'equipment': 'Thiết bị',
    'overview': 'Tổng quan',
    'instructions': 'Hướng dẫn',
    'tips': 'Mẹo',

    // Tracker
    'tracker': 'Theo dõi',
    'workoutTracker': 'Lịch tập',
    'mealPlanner': 'Dinh dưỡng',
    'today': 'Hôm nay',
    'noScheduleForDay': 'Chưa có lịch tập cho ngày này',
    'scheduleApiPending': 'API lịch tập chưa được xây dựng',
    'featureInProgress': 'Tính năng đang được phát triển',

    // AI Coach
    'aiCoach': 'AI Coach',
    'aiCoachSubtitle': 'Huấn luyện viên AI cá nhân',

    // Profile
    'profile': 'Hồ sơ',
    'language': 'Ngôn ngữ',
    'appearance': 'Giao diện',
    'themeLight': 'Sáng',
    'themeDark': 'Tối',
    'themeSystem': 'Theo hệ thống',
    'logout': 'Đăng xuất',
    'logoutConfirm': 'Bạn có chắc muốn đăng xuất?',
    'cancel': 'Huỷ',
    'notSignedIn': 'Chưa đăng nhập',
    'bodifyUser': 'Người dùng Bodify',

    // Auth
    'invalidEmail': 'Vui lòng nhập email hợp lệ',
    'enterPassword': 'Vui lòng nhập mật khẩu',
    'enterName': 'Vui lòng nhập tên của bạn',
    'passwordTooShort': 'Mật khẩu phải có ít nhất 6 ký tự',
    'acceptTerms': 'Vui lòng chấp nhận Điều khoản và Chính sách bảo mật',
    'loginFailed': 'Đăng nhập thất bại. Vui lòng thử lại.',
    'registerFailed': 'Đăng ký thất bại. Vui lòng thử lại.',
    'confirmEmailThenLogin':
        'Tạo tài khoản thành công. Xác nhận email rồi đăng nhập.',

    // BMI
    'bmi': 'BMI',
    'bmiTitle': 'BMI (Chỉ số khối cơ thể)',
    'bmiHistory': 'Lịch sử chỉ số',
    'viewMore': 'Xem thêm',
    'noBmiYet': 'Chưa có số đo nào',
    'noBmiHint': 'Nhập chiều cao và cân nặng để bắt đầu theo dõi',
    'recordMeasurement': 'Ghi số đo mới',
    'heightCm': 'Chiều cao (cm)',
    'weightKg': 'Cân nặng (kg)',
    'save': 'Lưu',
    'saved': 'Đã lưu số đo',
    'deleted': 'Đã xoá',
    'delete': 'Xoá',
    'deleteConfirm': 'Xoá số đo này?',
    'needHeightOrWeight': 'Nhập ít nhất chiều cao hoặc cân nặng',
    'invalidNumber': 'Giá trị không hợp lệ',
    'bmiUnderweight': 'Bạn đang thiếu cân',
    'bmiNormal': 'Cân nặng của bạn bình thường',
    'bmiOverweight': 'Bạn đang thừa cân',
    'bmiObese': 'Bạn đang béo phì',
    'bmiNeedBoth': 'Cần cả chiều cao và cân nặng để tính BMI',

    // Calendar month names
    'month1': 'Tháng 1', 'month2': 'Tháng 2', 'month3': 'Tháng 3',
    'month4': 'Tháng 4', 'month5': 'Tháng 5', 'month6': 'Tháng 6',
    'month7': 'Tháng 7', 'month8': 'Tháng 8', 'month9': 'Tháng 9',
    'month10': 'Tháng 10', 'month11': 'Tháng 11', 'month12': 'Tháng 12',

    // Calendar day headers, Monday first
    'dow1': 'T2', 'dow2': 'T3', 'dow3': 'T4', 'dow4': 'T5',
    'dow5': 'T6', 'dow6': 'T7', 'dow7': 'CN',
  };

  static const Map<String, String> _en = {
    'exercises': 'Exercises',
    'searchExercises': 'Search exercises...',
    'exerciseCount': 'exercises',
    'loading': 'Loading...',
    'noExercisesFound': 'No exercises found',
    'retry': 'Retry',

    'exerciseDetail': 'Exercise detail',
    'hasVideo': 'Video guide available',
    'muscles': 'Muscles',
    'equipment': 'Equipment',
    'overview': 'Overview',
    'instructions': 'Instructions',
    'tips': 'Tips',

    'tracker': 'Tracker',
    'workoutTracker': 'Workout',
    'mealPlanner': 'Meal Planner',
    'today': 'Today',
    'noScheduleForDay': 'No workout scheduled for this day',
    'scheduleApiPending': 'The schedule API has not been built yet',
    'featureInProgress': 'This feature is under development',

    'aiCoach': 'AI Coach',
    'aiCoachSubtitle': 'Your personal AI trainer',

    'profile': 'Profile',
    'language': 'Language',
    'appearance': 'Appearance',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'themeSystem': 'System',
    'logout': 'Log out',
    'logoutConfirm': 'Are you sure you want to log out?',
    'cancel': 'Cancel',
    'notSignedIn': 'Not signed in',
    'bodifyUser': 'Bodify user',

    'invalidEmail': 'Please enter a valid email',
    'enterPassword': 'Please enter your password',
    'enterName': 'Please enter your name',
    'passwordTooShort': 'Password must be at least 6 characters',
    'acceptTerms': 'Please accept the Privacy Policy and Terms of Use',
    'loginFailed': 'Login failed. Please try again.',
    'registerFailed': 'Registration failed. Please try again.',
    'confirmEmailThenLogin':
        'Account created. Confirm your email, then log in.',

    'bmi': 'BMI',
    'bmiTitle': 'BMI (Body Mass Index)',
    'bmiHistory': 'Measurement history',
    'viewMore': 'View More',
    'noBmiYet': 'No measurements yet',
    'noBmiHint': 'Enter your height and weight to start tracking',
    'recordMeasurement': 'Record a measurement',
    'heightCm': 'Height (cm)',
    'weightKg': 'Weight (kg)',
    'save': 'Save',
    'saved': 'Measurement saved',
    'deleted': 'Deleted',
    'delete': 'Delete',
    'deleteConfirm': 'Delete this measurement?',
    'needHeightOrWeight': 'Enter at least a height or a weight',
    'invalidNumber': 'Invalid value',
    'bmiUnderweight': 'You are underweight',
    'bmiNormal': 'You have a normal weight',
    'bmiOverweight': 'You are overweight',
    'bmiObese': 'You are obese',
    'bmiNeedBoth': 'Both height and weight are needed to compute BMI',

    'month1': 'January', 'month2': 'February', 'month3': 'March',
    'month4': 'April', 'month5': 'May', 'month6': 'June',
    'month7': 'July', 'month8': 'August', 'month9': 'September',
    'month10': 'October', 'month11': 'November', 'month12': 'December',

    'dow1': 'Mon', 'dow2': 'Tue', 'dow3': 'Wed', 'dow4': 'Thu',
    'dow5': 'Fri', 'dow6': 'Sat', 'dow7': 'Sun',
  };
}

/// Shorthand: `tr('exercises')`.
String tr(String key) => AppStrings.of(key);
