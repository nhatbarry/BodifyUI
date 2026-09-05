import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../common/app_colors.dart';
import '../../core/api_exception.dart';
import '../../core/app_strings.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

/// Reads GET /profile and writes PUT /profile.
class PersonalDataView extends StatefulWidget {
  const PersonalDataView({super.key});

  @override
  State<PersonalDataView> createState() => _PersonalDataViewState();
}

class _PersonalDataViewState extends State<PersonalDataView> {
  static const _genders = ['male', 'female', 'other'];

  final _nameController = TextEditingController();

  Profile? _profile;
  DateTime? _dateOfBirth;
  String? _gender;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _uploadingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService.instance.get();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile.name;
        _dateOfBirth = profile.dateOfBirth;
        // Only adopt a stored gender the picker can actually show; anything
        // else would silently reset to the first option on save.
        _gender = _genders.contains(profile.gender?.toLowerCase())
            ? profile.gender!.toLowerCase()
            : null;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage(tr('error_name_required'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      // The avatar is not part of this save: it is uploaded the moment it is
      // picked, so a user who chooses a photo and then backs out still has it.
      await ProfileService.instance.update(
        name: name,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        // Clearing a field needs an explicit null, which is different from
        // leaving the key out.
        clearDateOfBirth: _dateOfBirth == null && _profile?.dateOfBirth != null,
        clearGender: _gender == null && _profile?.gender != null,
      );
      if (!mounted) return;
      _showMessage(tr('toast_profile_saved'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return tr('label_gender_male');
      case 'female':
        return tr('label_gender_female');
      default:
        return tr('label_gender_other');
    }
  }

  static String _formatDate(DateTime value) =>
      "${value.day.toString().padLeft(2, '0')}/"
      "${value.month.toString().padLeft(2, '0')}/${value.year}";

  /// The avatar, with a button to replace or remove it.
  ///
  /// Uploading happens immediately rather than on Save. A picture is a file,
  /// not a form field: holding it in memory until the form is submitted means
  /// a user who picks a photo and then leaves loses it, and it would make the
  /// save request carry megabytes.
  Widget _buildAvatarPicker() {
    final colors = context.colors;
    final url = _profile?.avatarUrl;

    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 72,
            height: 72,
            child: _uploadingAvatar
                ? Container(
                    color: colors.surfaceVariant,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.primary1),
                    ),
                  )
                : url == null
                    ? Container(
                        color: colors.surfaceVariant,
                        alignment: Alignment.center,
                        child: Icon(Icons.person,
                            color: colors.textSecondary, size: 34),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        // Keyed on updated_at, not the URL: the signed URL is
                        // re-signed on every read, and a new upload must not
                        // keep showing the old picture from cache.
                        cacheKey:
                            'avatar-${_profile?.userId}-${_profile?.updatedAt.toIso8601String()}',
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: colors.surfaceVariant),
                        errorWidget: (_, __, ___) => Container(
                          color: colors.surfaceVariant,
                          alignment: Alignment.center,
                          child: Icon(Icons.person,
                              color: colors.textSecondary, size: 34),
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: _uploadingAvatar ? null : _pickAvatar,
                icon: Icon(Icons.photo_camera_outlined,
                    size: 18, color: colors.primary1),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero),
                label: Text(
                  url == null ? tr('btn_choose_photo') : tr('btn_change_photo'),
                  style: TextStyle(color: colors.primary1, fontSize: 13),
                ),
              ),
              if (url != null)
                TextButton(
                  onPressed: _uploadingAvatar ? null : _removeAvatar,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero),
                  child: Text(tr('btn_remove_photo'),
                      style: const TextStyle(
                          color: Color(0xFFE74C3C), fontSize: 13)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // A first pass on the device: the server crops and re-encodes anyway,
      // but sending a 4000 px original over a phone connection is wasteful.
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final profile =
          await ProfileService.instance.uploadAvatar(File(picked.path));
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _uploadingAvatar = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _uploadingAvatar = false);
      _showMessage(e.message);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final profile = await ProfileService.instance.removeAvatar();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _uploadingAvatar = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _uploadingAvatar = false);
      _showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        title: Text(
          tr('title_personal_data'),
          style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.primary1))
          : _error != null
              ? _buildError()
              : _buildForm(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: context.colors.textSecondary, size: 40),
          const SizedBox(height: 12),
          Text(_error!,
              style:
                  TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          TextButton(
            onPressed: _load,
            child: Text(tr('btn_retry'),
                style: TextStyle(color: context.colors.primary1)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final profile = _profile!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        if (profile.email != null) ...[
          Text(
            profile.email!,
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
        _label(tr('label_full_name')),
        _textField(_nameController, tr('label_full_name')),
        const SizedBox(height: 16),
        _label(tr('label_date_of_birth')),
        _tappableField(
          value: _dateOfBirth == null
              ? tr('label_not_set')
              : _formatDate(_dateOfBirth!),
          isPlaceholder: _dateOfBirth == null,
          icon: Icons.calendar_today_outlined,
          onTap: _pickDate,
          onClear:
              _dateOfBirth == null ? null : () => setState(() => _dateOfBirth = null),
        ),
        const SizedBox(height: 16),
        _label(tr('label_gender')),
        _buildGenderPicker(),
        const SizedBox(height: 16),
        _label(tr('label_avatar')),
        _buildAvatarPicker(),
        const SizedBox(height: 28),
        SizedBox(
          height: 48,
          child: _isSaving
              ? Center(
                  child:
                      CircularProgressIndicator(color: context.colors.primary1))
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: context.colors.primaryGradient),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextButton(
                    onPressed: _save,
                    child: Text(
                      tr('btn_save_changes'),
                      style: TextStyle(
                          color: context.colors.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(
          text,
          style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
      );

  Widget _textField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _tappableField({
    required String value,
    required bool isPlaceholder,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: isPlaceholder
                      ? context.colors.textSecondary
                      : context.colors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 18, color: context.colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderPicker() {
    return Row(
      children: [
        for (final value in _genders) ...[
          Expanded(
            child: GestureDetector(
              // Tapping the selected option clears it: gender is optional, and
              // otherwise there would be no way to unset it.
              onTap: () => setState(
                  () => _gender = _gender == value ? null : value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _gender == value
                      ? LinearGradient(colors: context.colors.primaryGradient)
                      : null,
                  color: _gender == value ? null : context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _genderLabel(value),
                  style: TextStyle(
                    color: _gender == value
                        ? context.colors.onPrimary
                        : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight:
                        _gender == value ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          if (value != _genders.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
