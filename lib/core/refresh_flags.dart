/// Marks which tabs hold data that changed somewhere else in the app, so
/// [MainTabView] only pays for a reload when something could actually be
/// different - not on every idle tap between tabs where nothing happened.
///
/// Each flag names the one real trigger behind it, because that trigger is
/// also the only place it gets set - grep the setter to find every path that
/// can make the flag's data stale.
class RefreshFlags {
  RefreshFlags._();

  /// `POST /workout-sessions/{id}/finish` is the only place records,
  /// achievements and completion stats are computed on the backend.
  /// Reopening and finishing again is a second real finish and lands here
  /// too; abandoning a session correctly does not, since it sets no records.
  static bool homeActivity = false;
  static bool profileAchievements = false;

  static void markWorkoutFinished() {
    homeActivity = true;
    profileAchievements = true;
  }

  /// `PUT /profile` from the personal-data screen. Only Home needs this flag:
  /// Profile's own header already refreshes itself on return from that screen
  /// via a plain `Navigator.push(...).then(_loadProfile)`, page-based and
  /// unaffected by tab switching. Home has no such path back to a screen
  /// reached through the Profile tab, so it has no other way to find out.
  static bool homeProfile = false;

  static void markProfileEdited() {
    homeProfile = true;
  }
}
