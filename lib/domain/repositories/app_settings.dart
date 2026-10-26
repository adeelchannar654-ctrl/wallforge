/// User-configurable application settings, as persisted.
///
/// This is deliberately a pure data snapshot with a JSON round-trip so the
/// persistence layer can store it without knowing anything about the UI.
///
/// **Scope is exactly what the app actually has today** (`phase.md` Phase 6
/// exit criterion: closing and reopening must not lose supported local data).
/// Two settings exist in the app, and only these two are persisted:
///
/// * [confirmWallPlacement] — the real `LocalGameController.toggleConfirmWallPlacement()`
///   toggle shown in the game HUD.
/// * [aiDifficulty] — the difficulty chosen on the entry screen.
/// * [tutorialCompleted] — set by the Phase 11 tutorial.
/// * [movementAssistance] — the Phase 11 Settings feature: while Move is
///   selected, the current player's shortest route to their goal is drawn
///   on the board. Added in Phase 11 because `design.md` §23 lists the
///   setting; it is a real, working feature, not a placeholder.
///
/// No theme, sound, haptics or accessibility setting is included: none of those
/// exist in the app yet, and inventing fields for them would be fabricating
/// settings. They can be added when they are actually implemented.
class AppSettings {
  const AppSettings({
    this.confirmWallPlacement = true,
    this.aiDifficulty = defaultAiDifficulty,
    this.tutorialCompleted = false,
    this.movementAssistance = false,
  });

  /// Factory-wide defaults, used when nothing is stored or the stored value is
  /// unreadable. Matches the app's own initial values.
  static const AppSettings defaults = AppSettings();

  /// The difficulty names the app currently offers.
  ///
  /// [aiDifficulty] is stored as a validated string rather than as a parallel
  /// domain enum on purpose. `AiDifficulty` lives in the application layer, and
  /// the domain must not depend on it; declaring a second enum here would create
  /// two lists that have to be kept in sync, and forgetting to add a fifth
  /// difficulty to both would silently fall back. A string with an explicit
  /// known-value check cannot drift.
  static const List<String> knownAiDifficulties = <String>[
    'easy',
    'medium',
    'hard',
    'expert',
  ];

  /// The app's default difficulty, matching `AiDifficulty.easy`.
  static const String defaultAiDifficulty = 'easy';

  /// Whether placing a wall asks for confirmation first.
  final bool confirmWallPlacement;

  /// The AI difficulty the player last chose, by name.
  ///
  /// Guaranteed to be one of [knownAiDifficulties]: [fromJson] substitutes the
  /// default for anything else.
  final String aiDifficulty;

  /// Whether the tutorial has been completed.
  ///
  /// Declared in Phase 6 as a reserved field so the persistence shape was
  /// complete when a tutorial landed; the Phase 11 tutorial is that producer.
  /// It flips when the learner finishes the tutorial or skips it — its
  /// product meaning is "the first-run tutorial offer has been resolved";
  /// the tutorial stays replayable from Home and Settings either way.
  final bool tutorialCompleted;

  /// Whether movement assistance is on: while Move is selected, the board
  /// draws the current player's shortest route to their goal row.
  ///
  /// `design.md` §23 lists the setting without defining it; Phase 11 scoped
  /// it to this behaviour (recorded in `memory.md` §13s). Defaults off, so
  /// the board is unchanged until the player opts in.
  final bool movementAssistance;

  AppSettings copyWith({
    bool? confirmWallPlacement,
    String? aiDifficulty,
    bool? tutorialCompleted,
    bool? movementAssistance,
  }) => AppSettings(
    confirmWallPlacement: confirmWallPlacement ?? this.confirmWallPlacement,
    aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    movementAssistance: movementAssistance ?? this.movementAssistance,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'confirmWallPlacement': confirmWallPlacement,
    'aiDifficulty': aiDifficulty,
    'tutorialCompleted': tutorialCompleted,
    'movementAssistance': movementAssistance,
  };

  /// Rebuilds settings from [json], substituting defaults for anything missing
  /// or malformed. Never throws: a corrupt stored value must not stop the app
  /// from starting.
  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final rawConfirm = json['confirmWallPlacement'];
    final rawDifficulty = json['aiDifficulty'];
    final rawTutorial = json['tutorialCompleted'];
    final rawAssistance = json['movementAssistance'];
    final difficultyIsKnown =
        rawDifficulty is String && knownAiDifficulties.contains(rawDifficulty);
    return AppSettings(
      confirmWallPlacement: rawConfirm is bool
          ? rawConfirm
          : defaults.confirmWallPlacement,
      aiDifficulty: difficultyIsKnown ? rawDifficulty : defaults.aiDifficulty,
      tutorialCompleted: rawTutorial is bool
          ? rawTutorial
          : defaults.tutorialCompleted,
      movementAssistance: rawAssistance is bool
          ? rawAssistance
          : defaults.movementAssistance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.confirmWallPlacement == confirmWallPlacement &&
      other.aiDifficulty == aiDifficulty &&
      other.tutorialCompleted == tutorialCompleted &&
      other.movementAssistance == movementAssistance;

  @override
  int get hashCode => Object.hash(
    confirmWallPlacement,
    aiDifficulty,
    tutorialCompleted,
    movementAssistance,
  );

  @override
  String toString() =>
      'AppSettings(confirmWallPlacement: $confirmWallPlacement, '
      'aiDifficulty: $aiDifficulty, '
      'tutorialCompleted: $tutorialCompleted, '
      'movementAssistance: $movementAssistance)';
}
