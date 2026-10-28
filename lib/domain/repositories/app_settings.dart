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
/// * [musicEnabled], [effectsEnabled], [volume] — the Phase 12 audio
///   settings (`design.md` §23's Audio group), gating the feedback layer's
///   background music and sound effects.
/// * [hapticsEnabled] — the Phase 12 haptics setting (§23's Haptics group).
/// * [reducedMotion] — the Phase 12 reduced-motion setting (§23's
///   Accessibility group). It became real in Phase 12, not Phase 13,
///   because `phase.md`'s Phase 12 task list names reduced-motion mode
///   explicitly and this phase builds the animation system it controls;
///   the correction is recorded in `memory.md` §13t.
/// * [colorAssistance], [highContrast], [uiScale] — the Phase 13
///   accessibility settings (§23's Accessibility group): a
///   colour-blind-safe player-colour swap for the board, the
///   high-contrast token set, and the app-wide text/UI scale. Recorded
///   in `memory.md` §13v.
///
/// No theme setting is included: none exists in the app, and inventing
/// fields for features that do not exist would be fabricating settings.
class AppSettings {
  const AppSettings({
    this.confirmWallPlacement = true,
    this.aiDifficulty = defaultAiDifficulty,
    this.tutorialCompleted = false,
    this.movementAssistance = false,
    this.musicEnabled = true,
    this.effectsEnabled = true,
    this.volume = defaultVolume,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.colorAssistance = false,
    this.highContrast = false,
    this.uiScale = defaultUiScale,
  });

  /// The default UI scale: unscaled.
  static const double defaultUiScale = 1.0;

  /// The largest UI scale the Settings control offers. 1.5 is the
  /// recorded Phase 13 bound: it is the largest factor at which every
  /// screen was layout-verified (`memory.md` §13v).
  static const double maxUiScale = 1.5;

  /// The default master volume.
  ///
  /// 0.5 because that is the value the Phase 11 Settings screen's inert
  /// Volume slider displayed; activating the slider in Phase 12 at the
  /// same value means the control did not silently jump.
  static const double defaultVolume = 0.5;

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

  /// Whether background music plays (Phase 12, `design.md` §23 Audio).
  ///
  /// Toggled independently from [effectsEnabled], per §23's grouping of
  /// Music and Effects as separate rows. Defaults on.
  final bool musicEnabled;

  /// Whether sound effects play (Phase 12, `design.md` §23 Audio).
  /// Defaults on.
  final bool effectsEnabled;

  /// Master volume for music and effects, 0.0–1.0 (Phase 12, §23 Audio).
  ///
  /// [fromJson] clamps out-of-range stored values rather than trusting
  /// them, so a corrupt store cannot produce a negative or >1 volume.
  final double volume;

  /// Whether haptic feedback fires (Phase 12, `design.md` §23 Haptics).
  /// Defaults on. Reduced motion suppresses haptics at the feedback layer
  /// regardless of this toggle (`design.md` §25).
  final bool hapticsEnabled;

  /// Whether the user asked for reduced motion in-app (Phase 12,
  /// `design.md` §23 Accessibility). Combined with the platform's own
  /// `MediaQuery.disableAnimations` signal at the feedback seam: either
  /// one being on means reduced motion is active. Defaults off.
  final bool reducedMotion;

  /// Whether colour assistance is on (Phase 13, §23 Accessibility):
  /// the board's player colours swap to the colour-blind-safe pair
  /// (Okabe–Ito blue/orange) verified in `memory.md` §13v, on top of
  /// the always-on §26 colour-plus-label redundancy. Defaults off.
  final bool colorAssistance;

  /// Whether the high-contrast token set is active (Phase 13, §23
  /// Accessibility): the app-wide alternate palette whose text pairs
  /// meet WCAG AA ratios (computed and recorded in `memory.md` §13v).
  /// Defaults off.
  final bool highContrast;

  /// The app-wide UI/text scale factor (Phase 13, §23 Accessibility),
  /// applied through `TextScaler`. [fromJson] clamps stored values to
  /// [defaultUiScale]–[maxUiScale], the range the Settings control
  /// offers and the layout tests cover. Defaults to [defaultUiScale].
  final double uiScale;

  AppSettings copyWith({
    bool? confirmWallPlacement,
    String? aiDifficulty,
    bool? tutorialCompleted,
    bool? movementAssistance,
    bool? musicEnabled,
    bool? effectsEnabled,
    double? volume,
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? colorAssistance,
    bool? highContrast,
    double? uiScale,
  }) => AppSettings(
    confirmWallPlacement: confirmWallPlacement ?? this.confirmWallPlacement,
    aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
    movementAssistance: movementAssistance ?? this.movementAssistance,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    effectsEnabled: effectsEnabled ?? this.effectsEnabled,
    volume: volume ?? this.volume,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    colorAssistance: colorAssistance ?? this.colorAssistance,
    highContrast: highContrast ?? this.highContrast,
    uiScale: uiScale ?? this.uiScale,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'confirmWallPlacement': confirmWallPlacement,
    'aiDifficulty': aiDifficulty,
    'tutorialCompleted': tutorialCompleted,
    'movementAssistance': movementAssistance,
    'musicEnabled': musicEnabled,
    'effectsEnabled': effectsEnabled,
    'volume': volume,
    'hapticsEnabled': hapticsEnabled,
    'reducedMotion': reducedMotion,
    'colorAssistance': colorAssistance,
    'highContrast': highContrast,
    'uiScale': uiScale,
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
    final rawMusic = json['musicEnabled'];
    final rawEffects = json['effectsEnabled'];
    final rawVolume = json['volume'];
    final rawHaptics = json['hapticsEnabled'];
    final rawReducedMotion = json['reducedMotion'];
    final rawColorAssistance = json['colorAssistance'];
    final rawHighContrast = json['highContrast'];
    final rawUiScale = json['uiScale'];
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
      musicEnabled: rawMusic is bool ? rawMusic : defaults.musicEnabled,
      effectsEnabled: rawEffects is bool ? rawEffects : defaults.effectsEnabled,
      volume: rawVolume is num
          ? rawVolume.toDouble().clamp(0.0, 1.0)
          : defaults.volume,
      hapticsEnabled: rawHaptics is bool ? rawHaptics : defaults.hapticsEnabled,
      reducedMotion: rawReducedMotion is bool
          ? rawReducedMotion
          : defaults.reducedMotion,
      colorAssistance: rawColorAssistance is bool
          ? rawColorAssistance
          : defaults.colorAssistance,
      highContrast: rawHighContrast is bool
          ? rawHighContrast
          : defaults.highContrast,
      uiScale: rawUiScale is num
          ? rawUiScale.toDouble().clamp(defaultUiScale, maxUiScale)
          : defaults.uiScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.confirmWallPlacement == confirmWallPlacement &&
      other.aiDifficulty == aiDifficulty &&
      other.tutorialCompleted == tutorialCompleted &&
      other.movementAssistance == movementAssistance &&
      other.musicEnabled == musicEnabled &&
      other.effectsEnabled == effectsEnabled &&
      other.volume == volume &&
      other.hapticsEnabled == hapticsEnabled &&
      other.reducedMotion == reducedMotion &&
      other.colorAssistance == colorAssistance &&
      other.highContrast == highContrast &&
      other.uiScale == uiScale;

  @override
  int get hashCode => Object.hash(
    confirmWallPlacement,
    aiDifficulty,
    tutorialCompleted,
    movementAssistance,
    musicEnabled,
    effectsEnabled,
    volume,
    hapticsEnabled,
    reducedMotion,
    colorAssistance,
    highContrast,
    uiScale,
  );

  @override
  String toString() =>
      'AppSettings(confirmWallPlacement: $confirmWallPlacement, '
      'aiDifficulty: $aiDifficulty, '
      'tutorialCompleted: $tutorialCompleted, '
      'movementAssistance: $movementAssistance, '
      'musicEnabled: $musicEnabled, '
      'effectsEnabled: $effectsEnabled, '
      'volume: $volume, '
      'hapticsEnabled: $hapticsEnabled, '
      'reducedMotion: $reducedMotion, '
      'colorAssistance: $colorAssistance, '
      'highContrast: $highContrast, '
      'uiScale: $uiScale)';
}
