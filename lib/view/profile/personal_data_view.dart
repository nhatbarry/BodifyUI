import 'package:flutter/material.dart';

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
  final _avatarController = TextEditingController();

  Profile? _profile;
  DateTime? _dateOfBirth;
  String? _gender;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
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
        _avatarController.text = profile.avatarUrl ?? '';
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
      _showMessage(tr('nameRequired'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final avatar = _avatarController.text.trim();
      await ProfileService.instance.update(
        name: name,
        avatarUrl: avatar.isEmpty ? null : avatar,
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        // Clearing a field needs an explicit null, which is different from
        // leaving the key out.
        clearDateOfBirth: _dateOfBirth == null && _profile?.dateOfBirth != null,
        clearGender: _gender == null && _profile?.gender != null,
      );
      if (!mounted) return;
      _showMessage(tr('profileSaved'));
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
        return tr('genderMale');
      case 'female':
        return tr('genderFemale');
      default:
        return tr('genderOther');
    }
  }

  static String _formatDate(DateTime value) =>
      "${value.day.toString().padLeft(2, '0')}/"
      "${value.month.toString().padLeft(2, '0')}/${value.year}";

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
          tr('personalData'),
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
            child: Text(tr('retry'),
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
        _label(tr('fullName')),
        _textField(_nameController, tr('fullName')),
        const SizedBox(height: 16),
        _label(tr('dateOfBirth')),
        _tappableField(
          value: _dateOfBirth == null
              ? tr('notSet')
              : _formatDate(_dateOfBirth!),
          isPlaceholder: _dateOfBirth == null,
          icon: Icons.calendar_today_outlined,
          onTap: _pickDate,
          onClear:
              _dateOfBirth == null ? null : () => setState(() => _dateOfBirth = null),
        ),
        const SizedBox(height: 16),
        _label(tr('gender')),
        _buildGenderPicker(),
        const SizedBox(height: 16),
        _label(tr('avatarUrl')),
        _textField(_avatarController, 'https://...'),
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
                      tr('saveChanges'),
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
