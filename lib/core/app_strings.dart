import 'app_locale.dart';

/// UI copy in both languages.
///
/// Deliberately a plain map rather than ARB/gen-l10n: the string count is small
/// and this keeps lookups usable from anywhere without a BuildContext.
///
/// Keys follow the `strings.xml` convention the Android app in
/// `D:\BodifyAIFitness` uses, so the two projects read the same way:
///
///   `app_`     the product itself           `app_name`
///   `title_`   a screen or dialog heading   `title_exercises`
///   `subtitle_` the line under a heading    `subtitle_what_goal`
///   `label_`   a field label or short noun  `label_email`
///   `btn_`     something you tap            `btn_save`
///   `hint_`    placeholder text in a field  `hint_search_exercises`
///   `msg_`     a sentence shown in the UI   `msg_no_exercises_found`
///   `error_`   why the input was refused    `error_invalid_email`
///   `toast_`   confirmation after an action `toast_saved`
///   `unit_`    a unit of measure            `unit_kg`
///   `nav_`     a tab or navigation label    `nav_tracker`
///   `dow_`/`month_`/`bmi_`/`goal_`  fixed vocabularies
///
/// `{n}` / `{name}` / `{done}` / `{total}` placeholders are substituted at the
/// call site with `replaceFirst`.
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
    // ---- App ----
    'app_name': 'Bodify',
    'app_tagline': 'Ai cũng có thể tập luyện',

    // ---- Common ----
    'label_email': 'Email',
    'label_password': 'Mật khẩu',
    'btn_cancel': 'Huỷ',
    'btn_save': 'Lưu',
    'btn_save_changes': 'Lưu thay đổi',
    'btn_delete': 'Xoá',
    'btn_remove': 'Bỏ khỏi ngày',
    'btn_clear': 'Xoá',
    'btn_rename': 'Đổi tên',
    'btn_retry': 'Thử lại',
    'btn_next': 'Tiếp tục',
    'btn_confirm': 'Xác nhận',
    'label_or': 'Hoặc',
    'msg_loading': 'Đang tải...',
    'msg_feature_in_progress': 'Tính năng đang được phát triển',
    'error_save_failed': 'Không lưu được. Vui lòng thử lại.',
    'error_invalid_number': 'Giá trị không hợp lệ',

    // ---- Onboarding ----
    'btn_get_started': 'Bắt đầu',
    'title_onboarding_1': 'Theo dõi mục tiêu',
    'desc_onboarding_1':
        'Đừng lo nếu bạn chưa biết đặt mục tiêu thế nào. Chúng tôi sẽ giúp bạn xác định và theo dõi mục tiêu của mình.',
    'title_onboarding_2': 'Đốt mỡ',
    'desc_onboarding_2':
        'Hãy tiếp tục đốt mỡ để đạt mục tiêu. Đau chỉ là tạm thời, còn bỏ cuộc hôm nay thì sẽ tiếc mãi.',
    'title_onboarding_3': 'Ăn uống lành mạnh',
    'desc_onboarding_3':
        'Cùng bắt đầu lối sống lành mạnh. Chúng tôi sẽ giúp bạn lên thực đơn mỗi ngày — ăn uống khoa học cũng rất thú vị.',
    'title_onboarding_4': 'Ngủ ngon hơn',
    'desc_onboarding_4':
        'Cải thiện chất lượng giấc ngủ cùng chúng tôi. Ngủ đủ và sâu sẽ cho bạn một buổi sáng tràn năng lượng.',

    // ---- Sign up ----
    'label_hey_there': 'Xin chào,',
    'title_create_account': 'Tạo tài khoản',
    'label_first_name': 'Tên',
    'label_last_name': 'Họ',
    'label_accept_terms':
        'Khi tiếp tục, bạn đồng ý với Chính sách bảo mật và\nĐiều khoản sử dụng',
    'btn_register': 'Đăng ký',
    'label_already_have_account': 'Đã có tài khoản? ',
    'btn_login_link': 'Đăng nhập',
    'error_enter_name': 'Vui lòng nhập tên của bạn',
    'error_accept_terms': 'Vui lòng chấp nhận Điều khoản và Chính sách bảo mật',
    'error_password_too_short': 'Mật khẩu phải có ít nhất 6 ký tự',
    'error_register_failed': 'Đăng ký thất bại. Vui lòng thử lại.',
    'toast_confirm_email':
        'Tạo tài khoản thành công. Xác nhận email rồi đăng nhập.',

    // ---- Login ----
    'title_welcome_back': 'Chào mừng trở lại',
    'btn_login': 'Đăng nhập',
    'label_no_account_yet': 'Chưa có tài khoản? ',
    'btn_register_link': 'Đăng ký',
    'error_invalid_email': 'Vui lòng nhập email hợp lệ',
    'error_enter_password': 'Vui lòng nhập mật khẩu',
    'error_login_failed': 'Đăng nhập thất bại. Vui lòng thử lại.',

    // ---- Forgot password ----
    'label_forgot_password': 'Quên mật khẩu?',
    'title_reset_password': 'Đặt lại mật khẩu',
    'hint_reset_password':
        'Nhập email của bạn, chúng tôi sẽ gửi liên kết đặt lại mật khẩu.',
    'btn_send_reset_link': 'Gửi liên kết',
    'toast_reset_link_sent':
        'Nếu email đã đăng ký, liên kết đặt lại đã được gửi.',

    // ---- Complete profile ----
    'title_complete_profile': 'Hoàn tất hồ sơ của bạn',
    'subtitle_complete_profile':
        'Thông tin này giúp chúng tôi hiểu bạn hơn!',
    'label_choose_gender': 'Chọn giới tính',
    'label_your_weight': 'Cân nặng của bạn',
    'label_your_height': 'Chiều cao của bạn',
    'unit_kg': 'KG',
    'unit_cm': 'CM',
    'error_need_both_measurements':
        'Nhập cả chiều cao và cân nặng, hoặc để trống cả hai',
    'error_measurement_numeric': 'Chiều cao và cân nặng phải là số',
    'error_height_range': 'Chiều cao phải trong khoảng 30 - 280 cm',
    'error_weight_range': 'Cân nặng phải trong khoảng 2 - 650 kg',

    // ---- Goal ----
    'title_what_goal': 'Mục tiêu của bạn là gì?',
    'subtitle_what_goal':
        'Chúng tôi sẽ chọn chương trình\nphù hợp nhất cho bạn',
    'goal_improve_shape': 'Cải thiện vóc dáng',
    'goal_improve_shape_desc':
        'Tôi ít mỡ thừa và muốn\ntăng thêm cơ bắp',
    'goal_lean_tone': 'Săn chắc',
    'goal_lean_tone_desc':
        'Tôi "gầy nhưng nhiều mỡ", trông mảnh\nnhưng không có dáng. Tôi muốn tăng cơ\nđúng cách',
    'goal_lose_fat': 'Giảm mỡ',
    'goal_lose_fat_desc':
        'Tôi cần giảm hơn 10 kg. Tôi muốn\nđốt hết phần mỡ này và tăng\nkhối lượng cơ',

    // ---- Welcome ----
    'title_welcome_user': 'Chào mừng, {name}',
    'subtitle_welcome':
        'Mọi thứ đã sẵn sàng, cùng chinh phục\nmục tiêu của bạn nào',
    'btn_go_to_home': 'Vào trang chủ',

    // ---- Home ----
    'label_welcome_back': 'Chào mừng trở lại,',
    'label_bodify_user': 'Người dùng Bodify',
    'label_today_target': 'Mục tiêu hôm nay',
    'btn_check': 'Xem',
    'title_activity_status': 'Tình trạng hoạt động',
    'label_heart_rate': 'Nhịp tim',
    'unit_bpm': 'BPM',
    'label_water_intake': 'Lượng nước',
    'label_realtime_updates': 'Cập nhật liên tục',
    'label_sleep': 'Giấc ngủ',
    'label_calories': 'Calo',
    'label_steps': 'Bước chân',
    'msg_not_connected': 'Chưa kết nối',
    'title_activity_progress': 'Hoạt động tập luyện',
    'label_month_short': 'T',
    'label_less': 'Ít',
    'label_more': 'Nhiều',
    'label_sets_this_week': '{n} set',
    'msg_no_activity_week': 'Chưa tập buổi nào trong tuần này',
    'label_kcal_left': 'còn {n} kCal',
    'title_workout_progress': 'Tiến độ tập luyện',
    'label_weekly': 'Theo tuần',
    'label_monthly': 'Theo tháng',

    // ---- Navigation ----
    'nav_tracker': 'Theo dõi',
    'nav_meal_planner': 'Dinh dưỡng',
    'nav_ai_coach': 'AI Coach',
    'subtitle_ai_coach': 'Huấn luyện viên AI cá nhân',
    'title_workout_tracker': 'Lịch tập',

    // ---- Exercise explorer ----
    'title_exercises': 'Bài tập',
    'hint_search_exercises': 'Tìm bài tập...',
    'label_exercise_count': 'bài tập',
    'msg_no_exercises_found': 'Không tìm thấy bài tập nào',

    // ---- Exercise detail ----
    'title_exercise_detail': 'Chi tiết bài tập',
    'label_has_video': 'Có video hướng dẫn',
    'label_muscles': 'Nhóm cơ',
    'label_equipment': 'Thiết bị',
    'label_overview': 'Tổng quan',
    'label_instructions': 'Hướng dẫn',
    'label_tips': 'Mẹo',
    'label_video_guide': 'Video hướng dẫn',
    'msg_video_tap_to_play': 'Chạm để phát. Video chỉ tải khi bạn bấm.',
    'msg_video_failed': 'Không tải được video. Chạm để thử lại.',

    // ---- Exercise picker ----
    'title_pick_exercises': 'Chọn bài tập',
    'label_selected_count': 'Đã chọn {n}',
    'msg_empty_selection_clears_day': 'Không chọn bài nào sẽ xoá ngày này',

    // ---- Schedules ----
    'msg_no_schedules': 'Chưa có lịch tập nào',
    'msg_no_schedules_hint': 'Bấm + để tạo lịch tập đầu tiên của bạn',
    'title_new_schedule': 'Lịch tập mới',
    'hint_schedule_name': 'VD: PPL cho người mới',
    'title_delete_schedule': 'Xoá lịch tập',
    'msg_delete_schedule_warning':
        'Xoá "{name}" sẽ xoá toàn bộ ngày tập và bài tập bên trong. Không thể hoàn tác.',
    'label_currently_following': 'Đang áp dụng',
    'label_workout_days_count': '{n} ngày có bài tập',
    'msg_no_workout_days': 'Chưa có ngày tập nào',
    'msg_schedule_api_pending': 'API lịch tập chưa được xây dựng',

    // ---- Calendar ----
    'label_today': 'Hôm nay',
    'label_rest_day': 'Ngày nghỉ',
    'msg_rest_day_blocked':
        'Xoá hết bài tập của ngày này trước khi đánh dấu ngày nghỉ',
    'btn_add_exercises': 'Thêm bài tập',
    'btn_add_to_today': 'Thêm vào hôm nay',
    'title_no_plan_yet': 'Chưa có lịch tập',
    'msg_create_plan_first': 'Bạn cần có lịch tập trước khi thêm bài vào hôm nay. Mở phần lịch tập để tạo?',
    'btn_create_plan': 'Tạo lịch tập',
    'btn_go_to_schedules': 'Tới lịch tập',
    'title_add_to_today': 'Thêm vào hôm nay?',
    'msg_add_to_today': 'Thêm "{name}" vào lịch hôm nay của "{plan}"?',
    'title_pick_plan': 'Thêm vào lịch nào?',
    'msg_pick_plan_activates': 'Lịch bạn chọn sẽ được đặt thành lịch đang áp dụng.',
    'title_already_added': 'Đã có rồi',
    'msg_already_in_today_long': '"{name}" đã có trong lịch hôm nay.',
    'title_rest_day': 'Hôm nay là ngày nghỉ',
    'msg_convert_rest_day': 'Bạn có muốn chuyển hôm nay thành ngày tập không?',
    'btn_convert_rest_day': 'Chuyển thành ngày tập',
    'toast_added_to_today': 'Đã thêm "{name}" vào hôm nay',
    'msg_no_active_plan': 'Chưa có lịch tập nào đang áp dụng',
    'msg_already_in_today': 'Bài này đã có trong hôm nay',
    'btn_edit_exercises': 'Sửa bài tập',
    'msg_no_schedule_for_day': 'Chưa có lịch tập cho ngày này',
    'label_not_trained': 'Chưa tập',
    'dow_mon': 'T2',
    'dow_tue': 'T3',
    'dow_wed': 'T4',
    'dow_thu': 'T5',
    'dow_fri': 'T6',
    'dow_sat': 'T7',
    'dow_sun': 'CN',
    'month_1': 'Tháng 1',
    'month_2': 'Tháng 2',
    'month_3': 'Tháng 3',
    'month_4': 'Tháng 4',
    'month_5': 'Tháng 5',
    'month_6': 'Tháng 6',
    'month_7': 'Tháng 7',
    'month_8': 'Tháng 8',
    'month_9': 'Tháng 9',
    'month_10': 'Tháng 10',
    'month_11': 'Tháng 11',
    'month_12': 'Tháng 12',

    // ---- Target sets ----
    'msg_no_target_sets': 'Chưa đặt set mục tiêu',
    'msg_no_target_sets_hint':
        'Chưa có set nào. Bấm "Thêm set" để đặt số rep, mức tạ và thời gian nghỉ.',
    'label_sets_total': '{n} set mục tiêu',
    'btn_add_set': 'Thêm set',
    'btn_add_exercise_to_session': 'Thêm bài tập vào buổi',
    'title_set_number': 'Set {n}',
    'label_reps': 'Rep',
    'label_weight': 'Tạ',
    'label_weight_kg': 'Cân nặng (kg)',
    'label_target_weight_kg': 'Tạ (kg)',
    'label_rest': 'Nghỉ',
    'label_rest_seconds': 'Nghỉ (giây)',
    'msg_empty_field_means_unset':
        'Để trống nghĩa là không đặt mục tiêu cho ô đó.',

    // ---- Workout session ----
    'btn_start_workout': 'Bắt đầu tập',
    'btn_continue_workout': 'Tiếp tục buổi tập',
    'btn_train_again': 'Tập tiếp',
    'btn_pause_workout': 'Tạm dừng',
    'btn_resume_workout': 'Tiếp tục',
    'btn_finish_workout': 'Kết thúc',
    'msg_finish_confirm':
        'Kết thúc buổi tập? Bạn vẫn có thể mở lại để tập tiếp sau.',
    'msg_finish_with_unlogged': 'Mới ghi {done}/{total} set. Kết thúc luôn?',
    'title_reopen_session': 'Tập tiếp?',
    'msg_reopen_session':
        'Buổi tập đã kết thúc. Mở lại để ghi thêm set? Thời gian nghỉ giữa hai lần sẽ không tính vào buổi tập.',
    'label_workout_in_progress': 'Đang tập',
    'label_workout_paused': 'Đang tạm dừng',
    'label_set_progress': '{done}/{total} set',
    'label_sets': 'Set',
    'label_volume': 'Khối lượng',
    'label_sessions': 'buổi',
    'label_planned_short': 'KH',
    'label_actual_short': 'TT',
    'label_not_logged': 'Chưa ghi',
    'msg_no_exercises_in_session':
        'Buổi tập này chưa có bài nào. Thêm bài vào lịch của ngày rồi bắt đầu lại.',
    'label_workout': 'Buổi tập',
    'title_latest_workout': 'Buổi tập gần đây',
    'title_recent_exercises': 'Các bài tập gần đây',
    'msg_no_recent_exercises': 'Chưa tập bài nào',
    'label_yesterday': 'Hôm qua',
    'label_range_7_days': '7 ngày',
    'label_range_1_month': '1 tháng',
    'label_range_1_year': '1 năm',
    'msg_no_workouts_in_range': 'Chưa có buổi tập nào trong khoảng này',

    // ---- BMI ----
    'label_bmi': 'BMI',
    'title_bmi': 'BMI (Chỉ số khối cơ thể)',
    'label_bmi_history': 'Lịch sử chỉ số',
    'bmi_underweight': 'Bạn đang thiếu cân',
    'bmi_normal': 'Cân nặng của bạn bình thường',
    'bmi_overweight': 'Bạn đang thừa cân',
    'bmi_obese': 'Bạn đang béo phì',
    'msg_no_bmi_yet': 'Chưa có số đo nào',
    'msg_no_bmi_hint': 'Nhập chiều cao và cân nặng để bắt đầu theo dõi',
    'title_record_measurement': 'Ghi số đo mới',
    'label_height_cm': 'Chiều cao (cm)',
    'error_need_height_or_weight': 'Nhập ít nhất chiều cao hoặc cân nặng',
    'error_bmi_need_both': 'Cần cả chiều cao và cân nặng để tính BMI',
    'btn_view_more': 'Xem thêm',
    'btn_see_more': 'Xem thêm',
    'msg_delete_confirm': 'Xoá số đo này?',
    'toast_deleted': 'Đã xoá',
    'toast_saved': 'Đã lưu số đo',

    // ---- Profile ----
    'title_profile': 'Hồ sơ',
    'title_personal_data': 'Thông tin cá nhân',
    'title_account_section': 'Tài khoản',
    'title_notification_section': 'Thông báo',
    'title_other_section': 'Khác',
    'label_achievement': 'Thành tích',
    'label_activity_history': 'Lịch sử hoạt động',
    'label_workout_progress': 'Tiến độ tập luyện',
    'label_contact_us': 'Liên hệ',
    'label_privacy_policy': 'Chính sách bảo mật',
    'label_setting': 'Cài đặt',
    'label_popup_notification': 'Thông báo đẩy',
    'btn_edit_profile': 'Sửa',
    'label_height': 'Chiều cao',
    'label_weight_short': 'Cân nặng',
    'label_age': 'Tuổi',
    'label_full_name': 'Họ và tên',
    'label_date_of_birth': 'Ngày sinh',
    'label_not_set': 'Chưa đặt',
    'label_gender': 'Giới tính',
    'label_gender_male': 'Nam',
    'label_gender_female': 'Nữ',
    'label_gender_other': 'Khác',
    'label_avatar': 'Ảnh đại diện',
    'btn_choose_photo': 'Chọn ảnh',
    'btn_change_photo': 'Đổi ảnh',
    'btn_remove_photo': 'Gỡ ảnh',
    'toast_profile_saved': 'Đã lưu thông tin',
    'error_name_required': 'Tên không được để trống',
    'error_not_signed_in': 'Chưa đăng nhập',

    // ---- Settings ----
    'label_language': 'Ngôn ngữ',
    'label_appearance': 'Giao diện',
    'label_theme_light': 'Sáng',
    'label_theme_dark': 'Tối',
    'label_theme_system': 'Theo hệ thống',
    'btn_logout': 'Đăng xuất',
    'title_account_security': 'Đăng nhập & bảo mật',
    'title_change_email': 'Đổi email',
    'title_change_password': 'Đổi mật khẩu',
    'label_new_email': 'Email mới',
    'label_current_password': 'Mật khẩu hiện tại',
    'label_new_password': 'Mật khẩu mới',
    'label_confirm_password': 'Nhập lại mật khẩu mới',
    'btn_change_email': 'Đổi email',
    'btn_change_password': 'Đổi mật khẩu',
    'error_enter_current_password': 'Vui lòng nhập mật khẩu hiện tại',
    'error_password_mismatch': 'Mật khẩu nhập lại không khớp',
    'msg_password_change_signs_out': 'Đổi mật khẩu sẽ đăng xuất khỏi mọi thiết bị.',
    'toast_email_changed': 'Đã đổi email. Kiểm tra hộp thư nếu cần xác nhận.',
    'toast_password_changed': 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.',
    'msg_logout_confirm': 'Bạn có chắc muốn đăng xuất?',

    // ---- Progress (Phase 4) ----
    'title_progress': 'Tiến độ',
    'label_completion': 'Hoàn thành',
    'label_performance': 'Hiệu suất',
    'label_frequency': 'Tần suất',
    'label_per_week': 'buổi/tuần',
    'label_total_volume': 'Tổng khối lượng',
    'msg_no_progress_yet': 'Chưa đủ dữ liệu để thống kê',
    'msg_no_progress_hint': 'Hoàn thành một buổi tập để bắt đầu theo dõi tiến độ',
    'hint_completion': 'Số set đã tập trên số set có trong kế hoạch',
    'hint_performance': 'So với mục tiêu đã đặt',

    // ---- Personal records (Phase 4) ----
    'title_personal_records': 'Kỷ lục cá nhân',
    'msg_no_records_yet': 'Chưa có kỷ lục nào',
    'msg_no_records_hint': 'Ghi lại một set để thiết lập kỷ lục đầu tiên',
    'label_pr_max_weight': 'Tạ nặng nhất',
    'label_pr_max_reps': 'Nhiều rep nhất',
    'label_pr_max_volume': 'Khối lượng cao nhất',
    'label_pr_max_duration': 'Giữ lâu nhất',
    'label_pr_max_distance': 'Xa nhất',
    'label_pr_estimated_1rm': '1RM ước tính',
    'label_record_count': '{n} kỷ lục',

    // ---- Achievements (Phase 4) ----
    'title_achievements': 'Thành tích',
    'label_unlocked_count': 'Đã mở khoá {done}/{total}',
    'label_locked': 'Chưa mở khoá',
    'msg_achievement_unlocked': 'Mở khoá thành tích!',
    'btn_nice': 'Tuyệt vời',
    'unit_workout': 'buổi',
    'unit_day': 'ngày',
    'unit_seconds': 'giây',
    'unit_reps': 'rep',
    'unit_record': 'kỷ lục',
    'unit_plan': 'giáo án',
    'unit_m': 'm',
    'label_duration_seconds': 'Thời lượng (giây)',
    'label_distance_m': 'Quãng đường (m)',
    'label_target_duration_seconds': 'Thời lượng mục tiêu (giây)',
    'label_target_distance_m': 'Quãng đường mục tiêu (m)',
    'label_target_reps': 'Rep mục tiêu',
  };

  static const Map<String, String> _en = {
    // ---- App ----
    'app_name': 'Bodify',
    'app_tagline': 'Everybody Can Train',

    // ---- Common ----
    'label_email': 'Email',
    'label_password': 'Password',
    'btn_cancel': 'Cancel',
    'btn_save': 'Save',
    'btn_save_changes': 'Save changes',
    'btn_delete': 'Delete',
    'btn_remove': 'Remove from day',
    'btn_clear': 'Clear',
    'btn_rename': 'Rename',
    'btn_retry': 'Retry',
    'btn_next': 'Next',
    'btn_confirm': 'Confirm',
    'label_or': 'Or',
    'msg_loading': 'Loading...',
    'msg_feature_in_progress': 'This feature is under development',
    'error_save_failed': 'Could not save. Please try again.',
    'error_invalid_number': 'Invalid value',

    // ---- Onboarding ----
    'btn_get_started': 'Get Started',
    'title_onboarding_1': 'Track Your Goal',
    'desc_onboarding_1':
        "Don't worry if you have trouble determining your goals, we can help you determine your goals and track them.",
    'title_onboarding_2': 'Get Burn',
    'desc_onboarding_2':
        "Let's keep burning to achieve your goals. It hurts only temporarily; if you give up now you will be in pain forever.",
    'title_onboarding_3': 'Eat Well',
    'desc_onboarding_3':
        "Let's start a healthy lifestyle with us. We can plan your diet every day - healthy eating is fun.",
    'title_onboarding_4': 'Improve Sleep Quality',
    'desc_onboarding_4':
        'Improve the quality of your sleep with us. Good sleep brings a good mood in the morning.',

    // ---- Sign up ----
    'label_hey_there': 'Hey there,',
    'title_create_account': 'Create an Account',
    'label_first_name': 'First Name',
    'label_last_name': 'Last Name',
    'label_accept_terms':
        'By continuing you accept our Privacy Policy and\nTerms of Use',
    'btn_register': 'Register',
    'label_already_have_account': 'Already have an account? ',
    'btn_login_link': 'Login',
    'error_enter_name': 'Please enter your name',
    'error_accept_terms': 'Please accept the Privacy Policy and Terms of Use',
    'error_password_too_short': 'Password must be at least 6 characters',
    'error_register_failed': 'Registration failed. Please try again.',
    'toast_confirm_email': 'Account created. Confirm your email, then log in.',

    // ---- Login ----
    'title_welcome_back': 'Welcome Back',
    'btn_login': 'Login',
    'label_no_account_yet': "Don't have an account yet? ",
    'btn_register_link': 'Register',
    'error_invalid_email': 'Please enter a valid email',
    'error_enter_password': 'Please enter your password',
    'error_login_failed': 'Login failed. Please try again.',

    // ---- Forgot password ----
    'label_forgot_password': 'Forgot your password?',
    'title_reset_password': 'Reset password',
    'hint_reset_password': 'Enter your email and we will send you a reset link.',
    'btn_send_reset_link': 'Send link',
    'toast_reset_link_sent':
        'If that email is registered, a reset link has been sent.',

    // ---- Complete profile ----
    'title_complete_profile': "Let's complete your profile",
    'subtitle_complete_profile': 'It will help us to know more about you!',
    'label_choose_gender': 'Choose Gender',
    'label_your_weight': 'Your Weight',
    'label_your_height': 'Your Height',
    'unit_kg': 'KG',
    'unit_cm': 'CM',
    'error_need_both_measurements':
        'Enter both height and weight, or leave both empty',
    'error_measurement_numeric': 'Height and weight must be numbers',
    'error_height_range': 'Height must be between 30 and 280 cm',
    'error_weight_range': 'Weight must be between 2 and 650 kg',

    // ---- Goal ----
    'title_what_goal': 'What is your goal?',
    'subtitle_what_goal': 'It will help us to choose a best\nprogram for you',
    'goal_improve_shape': 'Improve Shape',
    'goal_improve_shape_desc':
        'I have a low amount of body fat\nand need / want to build more\nmuscle',
    'goal_lean_tone': 'Lean & Tone',
    'goal_lean_tone_desc':
        'I\u2019m "skinny fat". I look thin but have\nno shape. I want to add lean\nmuscle the right way',
    'goal_lose_fat': 'Lose Fat',
    'goal_lose_fat_desc':
        'I have over 20 lbs to lose. I want to\ndrop all this fat and gain muscle\nmass',

    // ---- Welcome ----
    'title_welcome_user': 'Welcome, {name}',
    'subtitle_welcome':
        "You are all set now, let's reach your\ngoals together with us",
    'btn_go_to_home': 'Go To Home',

    // ---- Home ----
    'label_welcome_back': 'Welcome Back,',
    'label_bodify_user': 'Bodify user',
    'label_today_target': 'Today Target',
    'btn_check': 'Check',
    'title_activity_status': 'Activity Status',
    'label_heart_rate': 'Heart Rate',
    'unit_bpm': 'BPM',
    'label_water_intake': 'Water Intake',
    'label_realtime_updates': 'Real time updates',
    'label_sleep': 'Sleep',
    'label_calories': 'Calories',
    'label_steps': 'Steps',
    'msg_not_connected': 'Not connected',
    'title_activity_progress': 'Training activity',
    'label_month_short': 'M',
    'label_less': 'Less',
    'label_more': 'More',
    'label_sets_this_week': '{n} sets',
    'msg_no_activity_week': 'No workouts this week yet',
    'label_kcal_left': '{n} kCal left',
    'title_workout_progress': 'Workout Progress',
    'label_weekly': 'Weekly',
    'label_monthly': 'Monthly',

    // ---- Navigation ----
    'nav_tracker': 'Tracker',
    'nav_meal_planner': 'Meal Planner',
    'nav_ai_coach': 'AI Coach',
    'subtitle_ai_coach': 'Your personal AI trainer',
    'title_workout_tracker': 'Workout',

    // ---- Exercise explorer ----
    'title_exercises': 'Exercises',
    'hint_search_exercises': 'Search exercises...',
    'label_exercise_count': 'exercises',
    'msg_no_exercises_found': 'No exercises found',

    // ---- Exercise detail ----
    'title_exercise_detail': 'Exercise detail',
    'label_has_video': 'Video guide available',
    'label_muscles': 'Muscles',
    'label_equipment': 'Equipment',
    'label_overview': 'Overview',
    'label_instructions': 'Instructions',
    'label_tips': 'Tips',
    'label_video_guide': 'Video guide',
    'msg_video_tap_to_play':
        'Tap to play. The video downloads only when you ask.',
    'msg_video_failed': 'Could not load the video. Tap to retry.',

    // ---- Exercise picker ----
    'title_pick_exercises': 'Pick exercises',
    'label_selected_count': '{n} selected',
    'msg_empty_selection_clears_day': 'Saving with nothing ticked clears this date',

    // ---- Schedules ----
    'msg_no_schedules': 'No schedules yet',
    'msg_no_schedules_hint': 'Tap + to create your first schedule',
    'title_new_schedule': 'New schedule',
    'hint_schedule_name': 'e.g. PPL for beginners',
    'title_delete_schedule': 'Delete schedule',
    'msg_delete_schedule_warning':
        'Deleting "{name}" removes every workout day and exercise inside it. This cannot be undone.',
    'label_currently_following': 'Currently following',
    'label_workout_days_count': '{n} days with exercises',
    'msg_no_workout_days': 'No workout days yet',
    'msg_schedule_api_pending': 'The schedule API has not been built yet',

    // ---- Calendar ----
    'label_today': 'Today',
    'label_rest_day': 'Rest day',
    'msg_rest_day_blocked':
        'Remove this day\u2019s exercises before marking it a rest day',
    'btn_add_exercises': 'Add exercises',
    'btn_add_to_today': 'Add to today',
    'title_no_plan_yet': 'No schedule yet',
    'msg_create_plan_first': 'You need a schedule before adding an exercise to today. Open the schedules tab to make one?',
    'btn_create_plan': 'Create a schedule',
    'btn_go_to_schedules': 'Go to schedules',
    'title_add_to_today': 'Add to today?',
    'msg_add_to_today': 'Add "{name}" to today on "{plan}"?',
    'title_pick_plan': 'Add to which schedule?',
    'msg_pick_plan_activates': 'The one you pick becomes the schedule you are following.',
    'title_already_added': 'Already there',
    'msg_already_in_today_long': '"{name}" is already on today.',
    'title_rest_day': 'Today is a rest day',
    'msg_convert_rest_day': 'Turn today into a training day?',
    'btn_convert_rest_day': 'Make it a training day',
    'toast_added_to_today': 'Added "{name}" to today',
    'msg_no_active_plan': 'No schedule is currently active',
    'msg_already_in_today': 'That is already on today',
    'btn_edit_exercises': 'Edit exercises',
    'msg_no_schedule_for_day': 'No workout scheduled for this day',
    'label_not_trained': 'Not trained',
    'dow_mon': 'Mon',
    'dow_tue': 'Tue',
    'dow_wed': 'Wed',
    'dow_thu': 'Thu',
    'dow_fri': 'Fri',
    'dow_sat': 'Sat',
    'dow_sun': 'Sun',
    'month_1': 'January',
    'month_2': 'February',
    'month_3': 'March',
    'month_4': 'April',
    'month_5': 'May',
    'month_6': 'June',
    'month_7': 'July',
    'month_8': 'August',
    'month_9': 'September',
    'month_10': 'October',
    'month_11': 'November',
    'month_12': 'December',

    // ---- Target sets ----
    'msg_no_target_sets': 'No target sets yet',
    'msg_no_target_sets_hint':
        'No sets yet. Tap "Add set" to set reps, weight and rest time.',
    'label_sets_total': '{n} target sets',
    'btn_add_set': 'Add set',
    'btn_add_exercise_to_session': 'Add an exercise',
    'title_set_number': 'Set {n}',
    'label_reps': 'Reps',
    'label_weight': 'Weight',
    'label_weight_kg': 'Weight (kg)',
    'label_target_weight_kg': 'Weight (kg)',
    'label_rest': 'Rest',
    'label_rest_seconds': 'Rest (seconds)',
    'msg_empty_field_means_unset': 'Leaving a field empty means no target for it.',

    // ---- Workout session ----
    'btn_start_workout': 'Start workout',
    'btn_continue_workout': 'Continue workout',
    'btn_train_again': 'Train again',
    'btn_pause_workout': 'Pause',
    'btn_resume_workout': 'Resume',
    'btn_finish_workout': 'Finish',
    'msg_finish_confirm':
        'Finish this workout? You can reopen it later to keep training.',
    'msg_finish_with_unlogged': 'Only {done}/{total} sets logged. Finish anyway?',
    'title_reopen_session': 'Train again?',
    'msg_reopen_session':
        'This workout was finished. Reopen it to log more sets? The break between the two is not counted as training.',
    'label_workout_in_progress': 'In progress',
    'label_workout_paused': 'Paused',
    'label_set_progress': '{done}/{total} sets',
    'label_sets': 'Sets',
    'label_volume': 'Volume',
    'label_sessions': 'sessions',
    'label_planned_short': 'Plan',
    'label_actual_short': 'Done',
    'label_not_logged': 'Not logged',
    'msg_no_exercises_in_session':
        'No exercises in this workout. Add some to the day and start again.',
    'label_workout': 'Workout',
    'title_latest_workout': 'Latest workout',
    'title_recent_exercises': 'Recent exercises',
    'msg_no_recent_exercises': 'No exercises trained yet',
    'label_yesterday': 'Yesterday',
    'label_range_7_days': '7 days',
    'label_range_1_month': '1 month',
    'label_range_1_year': '1 year',
    'msg_no_workouts_in_range': 'No workouts in this period yet',

    // ---- BMI ----
    'label_bmi': 'BMI',
    'title_bmi': 'BMI (Body Mass Index)',
    'label_bmi_history': 'Measurement history',
    'bmi_underweight': 'You are underweight',
    'bmi_normal': 'You have a normal weight',
    'bmi_overweight': 'You are overweight',
    'bmi_obese': 'You are obese',
    'msg_no_bmi_yet': 'No measurements yet',
    'msg_no_bmi_hint': 'Enter your height and weight to start tracking',
    'title_record_measurement': 'Record a measurement',
    'label_height_cm': 'Height (cm)',
    'error_need_height_or_weight': 'Enter at least a height or a weight',
    'error_bmi_need_both': 'Both height and weight are needed to compute BMI',
    'btn_view_more': 'View More',
    'btn_see_more': 'See all',
    'msg_delete_confirm': 'Delete this measurement?',
    'toast_deleted': 'Deleted',
    'toast_saved': 'Measurement saved',

    // ---- Profile ----
    'title_profile': 'Profile',
    'title_personal_data': 'Personal Data',
    'title_account_section': 'Account',
    'title_notification_section': 'Notification',
    'title_other_section': 'Other',
    'label_achievement': 'Achievement',
    'label_activity_history': 'Activity History',
    'label_workout_progress': 'Workout Progress',
    'label_contact_us': 'Contact Us',
    'label_privacy_policy': 'Privacy Policy',
    'label_setting': 'Setting',
    'label_popup_notification': 'Pop-up Notification',
    'btn_edit_profile': 'Edit',
    'label_height': 'Height',
    'label_weight_short': 'Weight',
    'label_age': 'Age',
    'label_full_name': 'Full name',
    'label_date_of_birth': 'Date of birth',
    'label_not_set': 'Not set',
    'label_gender': 'Gender',
    'label_gender_male': 'Male',
    'label_gender_female': 'Female',
    'label_gender_other': 'Other',
    'label_avatar': 'Avatar',
    'btn_choose_photo': 'Choose photo',
    'btn_change_photo': 'Change photo',
    'btn_remove_photo': 'Remove photo',
    'toast_profile_saved': 'Profile saved',
    'error_name_required': 'Name cannot be empty',
    'error_not_signed_in': 'Not signed in',

    // ---- Settings ----
    'label_language': 'Language',
    'label_appearance': 'Appearance',
    'label_theme_light': 'Light',
    'label_theme_dark': 'Dark',
    'label_theme_system': 'System',
    'btn_logout': 'Log out',
    'title_account_security': 'Sign-in & security',
    'title_change_email': 'Change email',
    'title_change_password': 'Change password',
    'label_new_email': 'New email',
    'label_current_password': 'Current password',
    'label_new_password': 'New password',
    'label_confirm_password': 'Confirm new password',
    'btn_change_email': 'Change email',
    'btn_change_password': 'Change password',
    'error_enter_current_password': 'Please enter your current password',
    'error_password_mismatch': 'The passwords do not match',
    'msg_password_change_signs_out': 'Changing your password signs you out everywhere.',
    'toast_email_changed': 'Email changed. Check your inbox if confirmation is required.',
    'toast_password_changed': 'Password changed. Please sign in again.',
    'msg_logout_confirm': 'Are you sure you want to log out?',

    // ---- Progress (Phase 4) ----
    'title_progress': 'Progress',
    'label_completion': 'Completion',
    'label_performance': 'Performance',
    'label_frequency': 'Frequency',
    'label_per_week': 'per week',
    'label_total_volume': 'Total volume',
    'msg_no_progress_yet': 'Not enough data yet',
    'msg_no_progress_hint': 'Finish a workout to start tracking progress',
    'hint_completion': 'Sets done out of the sets your plan asked for',
    'hint_performance': 'Measured against the targets you set',

    // ---- Personal records (Phase 4) ----
    'title_personal_records': 'Personal records',
    'msg_no_records_yet': 'No records yet',
    'msg_no_records_hint': 'Log a set to set your first record',
    'label_pr_max_weight': 'Heaviest lift',
    'label_pr_max_reps': 'Most reps',
    'label_pr_max_volume': 'Best set volume',
    'label_pr_max_duration': 'Longest hold',
    'label_pr_max_distance': 'Furthest carry',
    'label_pr_estimated_1rm': 'Estimated 1RM',
    'label_record_count': '{n} records',

    // ---- Achievements (Phase 4) ----
    'title_achievements': 'Achievements',
    'label_unlocked_count': '{done}/{total} unlocked',
    'label_locked': 'Locked',
    'msg_achievement_unlocked': 'Achievement unlocked!',
    'btn_nice': 'Nice',
    'unit_workout': 'workouts',
    'unit_day': 'days',
    'unit_seconds': 'seconds',
    'unit_reps': 'reps',
    'unit_record': 'records',
    'unit_plan': 'plans',
    'unit_m': 'm',
    'label_duration_seconds': 'Duration (seconds)',
    'label_distance_m': 'Distance (m)',
    'label_target_duration_seconds': 'Target duration (seconds)',
    'label_target_distance_m': 'Target distance (m)',
    'label_target_reps': 'Target reps',
  };
}

/// Shorthand for `AppStrings.of(key)`.
String tr(String key) => AppStrings.of(key);
