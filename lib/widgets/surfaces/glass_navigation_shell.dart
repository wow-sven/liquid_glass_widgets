import 'package:flutter/foundation.dart'
    show ValueListenable, defaultTargetPlatform;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/widgets.dart';

import '../../constants/glass_defaults.dart';
import '../../src/engine/liquid_glass_settings.dart';
import '../../src/widgets/surfaces/vertical_bar_regions.dart';
import '../effects/glass_materialize.dart';
import '../overlays/glass_modal_sheet.dart';
import '../shared/glass_accessibility_scope.dart';
import 'glass_bar_item.dart';
import 'glass_large_title.dart';
import 'glass_vertical_bar.dart';
import 'shared/glass_nav_pinned_host.dart';

/// Shared timing for pinned header navigation. Route gestures retain their
/// route clock; branch changes use [branchDuration].
@immutable
class GlassHeaderMotion {
  /// Creates the header motion configuration.
  const GlassHeaderMotion({
    this.branchDuration = const Duration(milliseconds: 260),
    this.emptyGroupSizeCurve = Curves.easeInOut,
    this.emptyGroupFadeInCurve = Curves.easeInOutCubic,
    this.emptyGroupFadeOutCurve = Curves.easeInOutCubic,
  });

  /// Duration of header changes between retained Navigator branches.
  final Duration branchDuration;

  /// Full-clock size interpolation for a wide group and an empty endpoint.
  /// Single-button groups keep their existing materialize window.
  final Curve emptyGroupSizeCurve;

  /// Opacity of an entering wide group, independent of its size.
  final Curve emptyGroupFadeInCurve;

  /// Amount faded out of a leaving wide group, independent of its size.
  final Curve emptyGroupFadeOutCurve;
}

/// Renders one title face with the navigation clock. Incoming identifies the
/// selected endpoint; progress reverses with an interactive back gesture.
typedef GlassNavTitleTransitionBuilder = GlassBarContentTransitionBuilder;

/// Explicit endpoints for a same-page trailing action transition.
/// The page supplies progress, including reversals; route animations take priority.
@immutable
class GlassBarActionTransition {
  /// Creates a transition from [from] at zero to [to] at one.
  const GlassBarActionTransition({
    required this.from,
    required this.to,
    required this.progress,
  }) : assert(progress >= 0 && progress <= 1);

  /// Actions at the initial endpoint.
  final List<GlassBarItem> from;

  /// Actions at the final endpoint.
  final List<GlassBarItem> to;

  /// Page-owned progress in the inclusive range zero to one.
  final double progress;
}

/// What a single route contributes to the pinned navigation chrome.
///
/// Created by [GlassAppBar.pinned] bars and handed to the enclosing
/// [GlassNavigationShell]. Consumers never construct this directly.
@immutable
class GlassNavBarRegistration {
  /// Creates a registration describing one route's pinned bar chrome.
  const GlassNavBarRegistration({
    required this.actions,
    this.actionsTransition,
    this.leading = const <GlassBarItem>[],
    required this.showsBackButton,
    this.onBack,
    this.buttonSettings,
    this.buttonSize,
    this.toolbarHeight,
    @Deprecated(
      'A hoisted sheet item presents out of the hoisted capsule; the tap is '
      'no longer handed back.',
    )
    this.presentSheet,
    this.horizontalInset,
    this.platformViewBackdrop = false,
    this.largeTitleController,
    this.stripRowTop,
    this.title,
    this.titleContentKey,
    this.titleTransitionBuilder,
    this.itemMatching = GlassBarItemMatching.identity,
    this.contentTransition = GlassBarContentTransition.gel,
    this.routeDrivenTransitions = false,
  })  : assert(
          buttonSize == null || buttonSize > 0,
          'buttonSize must be positive',
        ),
        assert(
          toolbarHeight == null || toolbarHeight >= 0,
          'toolbarHeight must not be negative',
        );

  /// The trailing cluster items for this route.
  final List<GlassBarItem> actions;

  /// Optional same-page action morph, used only while navigation is settled.
  final GlassBarActionTransition? actionsTransition;

  /// A local action endpoint with all other chrome retained.
  GlassNavBarRegistration withActions(List<GlassBarItem> items) =>
      GlassNavBarRegistration(
        actions: items,
        leading: leading,
        showsBackButton: showsBackButton,
        onBack: onBack,
        buttonSettings: buttonSettings,
        buttonSize: buttonSize,
        toolbarHeight: toolbarHeight,
        horizontalInset: horizontalInset,
        platformViewBackdrop: platformViewBackdrop,
        largeTitleController: largeTitleController,
        stripRowTop: stripRowTop,
        title: title,
        titleContentKey: titleContentKey,
        titleTransitionBuilder: titleTransitionBuilder,
        // Local edits preserve business identity, unlike route slot matching.
        itemMatching: GlassBarItemMatching.identity,
        contentTransition: contentTransition,
        routeDrivenTransitions: routeDrivenTransitions,
      );

  /// The leading cluster items for this route, excluding the back button.
  ///
  /// Whether the back button also appears is [showsBackButton]'s business: the
  /// bar has already applied the replace-or-supplement rule by the time it
  /// registers, so the host reads one flag rather than re-deriving it.
  final List<GlassBarItem> leading;

  /// Whether this route shows the pinned back button.
  final bool showsBackButton;

  /// Overrides the default back action (`Navigator.maybePop`).
  final VoidCallback? onBack;

  /// Glass settings applied to this route's pinned chrome.
  final LiquidGlassSettings? buttonSettings;

  /// Diameter of standalone bar buttons (including the automatic back button
  /// and [GlassBarItemBackground.separate], [GlassBarItemBackground.own], and
  /// [GlassBarItemBackground.none] items), in logical pixels.
  ///
  /// Defaults to [GlassNavPinnedMetrics.backDiameter] (`44.0`). Shared
  /// multi-item capsules ([GlassBarItemBackground.shared]) use
  /// `buttonSize + (GlassNavPinnedMetrics.slot - GlassNavPinnedMetrics.backDiameter)`
  /// (`buttonSize + 2.0`), preserving the `46 / 44` ratio.
  ///
  /// Ignored in iPhone Duo's vertical bar strip, where controls use
  /// [GlassVerticalBarMetrics.controlExtent].
  final double? buttonSize;

  /// Height of the horizontal toolbar row that the pinned chrome centres
  /// within, in logical pixels.
  ///
  /// Defaults to [GlassNavPinnedMetrics.toolbarHeight] (`44.0`), or
  /// [buttonSize] when [buttonSize] is larger.
  final double? toolbarHeight;

  /// No longer called: a [GlassBarItem.sheet] presents out of the hoisted
  /// capsule itself, which the shell keeps through the presentation. See
  /// [GlassNavigationShellState.holdForSheet].
  @Deprecated(
    'A hoisted sheet item presents out of the hoisted capsule; the tap is no '
    'longer handed back.',
  )
  final void Function(GlassBarSheetItem item)? presentSheet;

  /// Inset from each screen edge to the pinned chrome, in logical pixels.
  ///
  /// Defaults to [GlassNavPinnedMetrics.horizontalPadding], which is what
  /// [GlassAppBar] insets its own chrome by — so a bar the package draws at
  /// both ends already agrees with itself and passes nothing.
  ///
  /// A bar the app draws is the case for it. The chrome hoists and hands back
  /// on its own schedule — a presented sheet gives it to the route, a
  /// transition takes it away again — and each hand-over is invisible only
  /// while the two renderings land on the same guide. A bar aligned to its
  /// app's page gutter rather than to this default passes that gutter here.
  final double? horizontalInset;

  /// Distance from the top of the screen to the row that keeps the items
  /// staying horizontal, in iPhone Duo's vertical bar strip.
  ///
  /// Defaults to [GlassVerticalBarMetrics.edgeMargin], the row [GlassAppBar]
  /// draws its title in. A bar the app draws with a header of its own passes the top
  /// of that header's row, so the items land in it rather than above it.
  /// Elsewhere it is not read.
  final double? stripRowTop;

  /// Optional compact title hoisted with the horizontal navigation chrome.
  /// Use the resolved title slot in the bar builder to avoid drawing it twice.
  final Widget? title;

  /// Visible title identity. Equal non-null values retain the title unchanged.
  final Object? titleContentKey;

  /// Optional title presentation driven by the shell's exact route progress.
  final GlassNavTitleTransitionBuilder? titleTransitionBuilder;

  /// Matching policy for presentation slots across different routes.
  final GlassBarItemMatching itemMatching;

  /// Foreground replacement policy, separate from glass splitting and merging.
  final GlassBarContentTransition contentTransition;

  /// Follow the route's exact progress in both directions, including cancelled
  /// back gestures. Disables the native gesture hold and independently timed gel.
  final bool routeDrivenTransitions;

  /// Whether the pinned chrome floats over a native platform view.
  ///
  /// The shell draws a hoisted cluster with its own [GlassButton], and the
  /// shader that button uses reads a captured backdrop the platform view is
  /// never part of — so over a map or a video the capsule has nothing to
  /// refract and renders inert, whatever [buttonSettings] asks for. Only a
  /// live `BackdropFilter` samples the composited view, and this is what
  /// routes the shell's copy there, exactly as [GlassButton.platformViewBackdrop]
  /// does for the bar's own.
  final bool platformViewBackdrop;

  /// The large title this route's bar collapses with, if any.
  ///
  /// Only read in iPhone Duo's vertical bar strip, where the title row holds
  /// the large title: the items that stay horizontal share that row, so they
  /// scroll away with the title, and the whole chrome hides while the title's
  /// search is open ([GlassLargeTitleController.isSearchPresented]).
  final GlassLargeTitleController? largeTitleController;

  /// The tappable items in [actions], with spacers removed.
  List<GlassBarActionItem> get actionItems =>
      actions.whereType<GlassBarActionItem>().toList(growable: false);

  /// The tappable items in [leading], with spacers removed.
  List<GlassBarActionItem> get leadingItems =>
      leading.whereType<GlassBarActionItem>().toList(growable: false);
}

/// Marks an active branch of retained sibling Navigators.
///
/// This is selection metadata, not a chrome host. Wrap each cached tab's
/// Navigator and mark only the selected branch active. Nested inactive branches
/// stay inactive; a separate [GlassNavigationShell] starts a new boundary.
class GlassNavigationBranch extends StatelessWidget {
  /// Declares whether [child] belongs to the selected navigation branch.
  const GlassNavigationBranch({
    required this.active,
    required this.child,
    super.key,
  });

  /// Whether this branch is selected by its navigation container.
  final bool active;

  /// The retained Navigator subtree.
  final Widget child;

  /// Whether [context] belongs to the selected branch of its nearest shell.
  static bool isActiveOf(BuildContext context) {
    final branch =
        context.dependOnInheritedWidgetOfExactType<_GlassBranchScope>();
    final shell = GlassNavigationShell.maybeOf(context);
    return branch == null || branch.shell != shell || branch.active;
  }

  @override
  Widget build(BuildContext context) => _GlassBranchScope(
        active: active && isActiveOf(context),
        shell: GlassNavigationShell.maybeOf(context),
        child: child,
      );
}

class _GlassBranchScope extends InheritedWidget {
  const _GlassBranchScope({
    required this.active,
    required this.shell,
    required super.child,
  });
  final bool active;
  final GlassNavigationShellState? shell;

  @override
  bool updateShouldNotify(_GlassBranchScope oldWidget) =>
      active != oldWidget.active || shell != oldWidget.shell;
}

/// Hosts navigation-bar glass chrome **above** the [Navigator], so it stays
/// pinned while route content slides during a push or pop.
///
/// This reproduces the iOS 26 navigation bar model, where bar items belong to
/// the navigation stack rather than to any one screen. Apple documents the
/// behaviour on `UIBarButtonItem.identifier`: *"When the set of bar button
/// items in a navigation bar or toolbar changes (for example, when pushing or
/// popping view controllers), UIKit automatically animates the transition
/// between the different sets of items."*
///
/// Install it once, wrapping whatever [Navigator] your app builds. This works
/// with the imperative [Navigator] and with any router built on the Pages API
/// (go_router, auto_route, beamer), because the shell only ever reads
/// [ModalRoute] animations — it never intercepts navigation:
///
/// ```dart
/// CupertinoApp(
///   builder: (context, child) => GlassNavigationShell(child: child!),
///   home: const HomeScreen(),
/// );
///
/// // Or with a router:
/// CupertinoApp.router(
///   routerConfig: router,
///   builder: (context, child) => GlassNavigationShell(child: child!),
/// );
/// ```
///
/// Nested Navigators share this host: their active leaf supplies the header,
/// while the enclosing route drives transitions into or out of the whole flow.
/// Retained sibling Navigators declare selection with [GlassNavigationBranch];
/// the shell supplies a short header transition when selection changes without
/// a route animation. Switching back reverses that transition.
/// Use another shell only for a separate presentation surface, such as a sheet.
/// A shell inside a popup route keeps the enclosing shell's header in-route
/// until that popup's exit animation finishes.
///
/// Screens opt in with the [GlassAppBar.pinned] constructor. Screens using
/// the plain [GlassAppBar] are unaffected, and when no shell is present (or
/// the device can't render the effect) pinned bars fall back to rendering the
/// same buttons inside the route.
class GlassNavigationShell extends StatefulWidget {
  /// Creates a navigation shell around [child].
  const GlassNavigationShell({
    super.key,
    required this.child,
    this.enabled = true,
    this.headerMotion = const GlassHeaderMotion(),
    this.effectTransition = GlassEffectTransition.materialize,
    this.swipeCommitTransition = GlassSwipeCommitTransition.effect,
    this.verticalBarBehavior = GlassVerticalBarBehavior.automatic,
    this.verticalBarCompression = GlassVerticalBarCompression.automatic,
  });

  /// The subtree containing the [Navigator], typically the `child` handed to
  /// `CupertinoApp.builder`.
  final Widget child;

  /// Whether pinning is enabled at all.
  ///
  /// When false the shell is inert and every screen renders its bar chrome
  /// in-route, exactly as if no shell were installed.
  final bool enabled;

  /// Shared header timing, independent of page and foreground content.
  final GlassHeaderMotion headerMotion;

  /// How chrome that appears or disappears across a transition animates —
  /// a back button on the first push off the root, an actions capsule on a
  /// route whose destination has none.
  ///
  /// Defaults to [GlassEffectTransition.materialize], mirroring iOS 26.
  /// [GlassEffectTransition.identity] restores the single switch at the
  /// transition midpoint, which is what reduce motion selects too.
  ///
  /// Set on the shell rather than per screen because the choreography spans
  /// two routes: with a knob on each bar, a push between routes that disagree
  /// would have no answer for which one wins.
  final GlassEffectTransition effectTransition;

  /// How the chrome transitions once an interactive back-swipe commits.
  ///
  /// Defaults to [GlassSwipeCommitTransition.effect], which plays
  /// [effectTransition] as for any other pop.
  final GlassSwipeCommitTransition swipeCommitTransition;

  /// Whether bars move into iPhone Duo's vertical bar strip.
  ///
  /// Defaults to [GlassVerticalBarBehavior.automatic]: where the device
  /// reserves a strip, the pinned chrome stacks in it — back button first,
  /// then the leading and trailing groups in order — and the title stays in a
  /// horizontal row at the top of the content, beside any item that stays
  /// horizontal (see [GlassBarActionItem.axisBehavior]). [GlassTabBar.bottom]
  /// and [GlassToolbar] follow, from the bottom of the strip up. Read the
  /// result with [GlassVerticalBar.maybeOf].
  ///
  /// Only the shell's own subtree follows, and only while [enabled]: UIKit
  /// moves the bars a container owns and no others.
  final GlassVerticalBarBehavior verticalBarBehavior;

  /// What gives way when the vertical bar strip runs out of height.
  ///
  /// Defaults to [GlassVerticalBarCompression.automatic]. Set on the shell
  /// because the choice is between the tab bar and the pinned chrome, which
  /// only the shell sees together.
  final GlassVerticalBarCompression verticalBarCompression;

  /// The nearest enclosing shell, or null if there is none.
  static GlassNavigationShellState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_GlassNavigationShellScope>()
        ?.state;
  }

  /// Whether the enclosing hoisted header is changing navigation endpoints.
  /// Foregrounds can suspend local animations while the shell drives them.
  /// False outside the hoisted header; route bodies keep their own motion.
  static bool isTransitioningOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_GlassHeaderMotionScope>()
          ?.transitioning ??
      false;

  /// Motion configuration of the enclosing hoisted header.
  static GlassHeaderMotion headerMotionOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_GlassHeaderMotionScope>()
          ?.motion ??
      const GlassHeaderMotion();

  @override
  State<GlassNavigationShell> createState() => GlassNavigationShellState();
}

/// Registry and animation clock for a [GlassNavigationShell].
///
/// Routes register through [register]. Stack order is resolved within each
/// Navigator, then nested Navigators supply their active leaf's chrome. An
/// ancestor transition drives that chrome when entering or leaving a flow.
class GlassNavigationShellState extends State<GlassNavigationShell>
    with TickerProviderStateMixin {
  /// Registrations keyed by route, in registration order.
  final Map<ModalRoute<dynamic>, GlassNavBarRegistration> _registry =
      <ModalRoute<dynamic>, GlassNavBarRegistration>{};

  /// Identifies the instance allowed to release each route's current chrome.
  final Map<ModalRoute<dynamic>, Object?> _registrationOwners =
      <ModalRoute<dynamic>, Object?>{};

  // Paths run from this presentation boundary down to the declaring route.
  final Map<ModalRoute<dynamic>, List<ModalRoute<dynamic>>> _routePaths = {};
  final Set<ModalRoute<dynamic>> _inactiveRoutes = {};

  // A sheet-local shell publishes its presentation to the enclosing shell.
  // The covered page becomes current at pop START, before the modal has left.
  final Map<GlassNavigationShellState, PopupRoute<dynamic>> _presentations = {};
  GlassNavigationShellState? _presentationParent;
  PopupRoute<dynamic>? _presentationRoute;

  // Branch selection has no route animation. Keep its endpoints in this host,
  // so the same title/controls renderer can animate across retained Navigators.
  _GlassNavigationResolution? _lastNavigation;
  _GlassNavigationResolution? _branchFrom, _branchTo;
  late final AnimationController _branchClock = AnimationController(
    vsync: this,
    duration: widget.headerMotion.branchDuration,
    value: 1,
  );
  double? _branchPendingProgress;
  double _branchTarget = 1;
  int _branchRevision = 0;

  /// Routes whose animations this shell currently listens to.
  final Set<Animation<double>> _listened = <Animation<double>>{};

  /// Fires whenever the rendered chrome may have changed.
  final _TickNotifier _tick = _TickNotifier();

  /// Notifies when the answer [isHoisting] gives may have changed.
  ///
  /// Registrants follow this rather than reading the routes themselves, so
  /// that the bar and the shell always swap in the same frame.
  Listenable get chromeChanges => _tick;

  /// Whether a deferred notification is already queued for this frame.
  bool _notifyQueued = false;

  // ---------------------------------------------------------------------------
  // Interactive back-swipe hold
  // ---------------------------------------------------------------------------
  // The chrome's own transition waits for the gesture to commit rather than
  // scrubbing under the finger. Dragging halfway and letting go should not
  // have half-dissolved a button on the way — until the pop is committed
  // there is no answer yet to which chrome wins, and animating toward one
  // reads as the bar guessing. The page and its title still track the drag;
  // it is only the pinned chrome that waits.

  /// Whether a user gesture was in progress on the previous resolve.
  bool _gestureActive = false;

  /// Chrome progress frozen at the moment the gesture began.
  double? _gestureHeldProgress;

  /// The most recent progress observed with no gesture running.
  ///
  /// A drag is already under way by the time the shell first resolves during
  /// it, so this is what the chrome is held at rather than the value on that
  /// first frame.
  double? _ungesturedProgress;

  /// Plays the chrome's transition after a swipe commits.
  ///
  /// The chrome cannot ride the route's remaining travel here. Cupertino
  /// sizes the commit animation by how far the drag got —
  /// `lerpDouble(0, maxDroppedSwipeTime, controller.value)` — so releasing
  /// late leaves almost nothing to play over, and the whole dissolve was
  /// being squeezed into about five frames. Given its own duration it always
  /// reads, at the price of outliving the page transition on a late release.
  late final AnimationController _commitExit = AnimationController(
    vsync: this,
    duration: GlassDefaults.dematerializeDuration,
  );

  /// The chrome as it stood when the swipe committed, or null when no commit
  /// is playing.
  ///
  /// Frozen because the outgoing route unregisters the moment its pop
  /// finishes, which is *before* this animation ends. Resolving from the live
  /// registry would flip `from`/`to` mid-play and snap the chrome — the exact
  /// thing the fixed duration exists to avoid.
  GlassNavPinnedState? _commitExitSnapshot;

  /// Chrome progress the commit animation starts from.
  double _commitExitStart = 1.0;

  // ---------------------------------------------------------------------------
  // The chrome's own clock
  // ---------------------------------------------------------------------------
  // The choreography is timed against a route whose animation value is linear
  // in time, which is what a duration-driven controller gives it. A route
  // running a `Simulation` instead — a spring — reports a value that covers
  // most of its travel in the first fraction of the flight and then creeps,
  // so following it squeezed the whole morph into a few frames while the page
  // was still moving. Such a route's chrome plays on its own controller over
  // the route's declared `transitionDuration` (or `reverseTransitionDuration`)
  // instead, which is the morph its duration promised. A duration-driven
  // route is left on its own value, so it reads exactly as before; a
  // back-swipe still scrubs the route's value, and a committed swipe is
  // [_commitExit]'s.

  /// Plays a sprung push or pop's chrome over the route's declared duration.
  late final AnimationController _clock = AnimationController(vsync: this);

  /// The route and direction [_clock] is playing, or null at rest.
  ModalRoute<dynamic>? _clockRoute;
  AnimationStatus? _clockStatus;

  /// Where the current run starts from, held until the deferred start.
  ///
  /// A run begins from wherever the chrome already is, so a pop that
  /// interrupts a push carries on from mid-morph rather than restarting at
  /// the far end. Read in place of the controller while [_clockPending].
  double _clockFrom = 0.0;

  /// Whether a run has been scheduled but the controller not yet started.
  bool _clockPending = false;

  /// Each registered route's status listener, so it can be removed again.
  final Map<ModalRoute<dynamic>, AnimationStatusListener> _clockListeners =
      <ModalRoute<dynamic>, AnimationStatusListener>{};

  // Cupertino can stop its gesture after the final animation notification.
  // Observe that boundary too so a cancelled swipe restores hit testing.
  final Map<ModalRoute<dynamic>, ValueListenable<bool>> _gestureNotifiers = {};

  // ---------------------------------------------------------------------------
  // Sheet hold
  // ---------------------------------------------------------------------------
  // A presentation hands the chrome back to its route, because the shell draws
  // above the Navigator and cannot get beneath a sheet. The capsule a sheet
  // morphs out of is the exception: the morph has emptied it, so nothing of it
  // is drawn above the sheet — and handing it back would take the anchor out
  // from under the droplet mid-flight, and leave the route's copy painted
  // under the barrier where the emptied capsule should be. That one group
  // stays hoisted for as long as its trigger is standing in for the sheet.

  /// The capsule kept hoisted through the sheet presented out of it, or null.
  _SheetHold? _sheetHold;

  bool _pinningSupported = false;

  /// Whether pinning is currently active.
  ///
  /// False when the shell is disabled or the resolved glass quality can't
  /// render the effect, in which case registrants render in-route instead.
  bool get isActive => widget.enabled && _pinningSupported;

  @override
  void initState() {
    super.initState();
    _commitExit
      ..addListener(_tick.notify)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _commitExitSnapshot = null;
        _clearGestureHold();
        // Back to rest so the next commit holds at its snapshot rather than
        // starting from a controller still parked at 1.0.
        _commitExit.reset();
        _scheduleNotify();
      });
    _clock
      ..addListener(_tick.notify)
      // The frame the run ends is the frame the chrome settles.
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _scheduleNotify();
      });
    _branchClock
      ..addListener(_scheduleNotify)
      ..addStatusListener((_) => _scheduleNotify());
    VerticalBarRegions.instance.addListener(_onVerticalBarRegions);
    VerticalBarRegions.instance.edge.addListener(_onVerticalBarRegions);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = GlassNavigationShell.maybeOf(context);
    final route = ModalRoute.of(context);
    final presentation = route is PopupRoute<dynamic> ? route : null;
    if (parent != _presentationParent || presentation != _presentationRoute) {
      _presentationParent?._setPresentation(this, null);
      _presentationParent = parent;
      _presentationRoute = presentation;
      parent?._setPresentation(this, presentation);
    }
    // Pinning is chrome GEOMETRY: it hoists the registered bar out of the
    // route into the shell so it survives the transition. It costs no shader
    // of its own, and the pinned bar still renders through the normal glass
    // path — GlassNavPinnedHost resolves its own quality — so at `minimal` it
    // is simply a BackdropFilter-only bar that stays put across routes, which
    // is the correct degraded behaviour rather than a reason to switch the
    // feature off.
    //
    // This used to mirror the modal sheet morph's gate
    // (`quality != GlassQuality.minimal`). That borrowed the blur's
    // capability floor for something that does not depend on it: the sheet
    // morph asks whether real glass can be drawn, and pinning never needed an
    // answer to that.
    //
    // It also meant an adaptive decision about blur cost silently changed an
    // unrelated layout behaviour. `minimal` is not only a developer opt-in —
    // GlassQualityAdapter steps down to it on its own when frame times
    // regress, which a debug build reaches routinely just by being a debug
    // build — so pinning switched itself off during ordinary local
    // development, and on any app deliberately shipping `minimal` for low-end
    // devices, which are exactly the devices where a per-route bar rebuild is
    // most visible.
    final supported = debugPinningSupported ?? true;
    if (supported != _pinningSupported) {
      _pinningSupported = supported;
    }
  }

  /// Overrides the capability gate in tests, where no GPU is available.
  @visibleForTesting
  static bool? debugPinningSupported;

  // ---------------------------------------------------------------------------
  // Registry
  // ---------------------------------------------------------------------------

  /// Registers or updates [route]'s pinned chrome.
  ///
  /// Pass a stable [owner] for the lifetime of the registering bar. A new bar
  /// may replace the same route's registration before the old bar is disposed;
  /// only the current owner can [unregister] it. Owners compare by identity.
  /// Omitting the owner retains support for route-owned manual registrations.
  /// [active] comes from [GlassNavigationBranch] for retained tab Navigators.
  /// Inactive declarations stay hoisted but cannot own the visible header.
  void register(
    ModalRoute<dynamic> route,
    GlassNavBarRegistration registration, {
    Object? owner,
    bool active = true,
  }) {
    _registry[route] = registration;
    _registrationOwners[route] = owner;
    active ? _inactiveRoutes.remove(route) : _inactiveRoutes.add(route);
    _routePaths[route] = _pathOf(route);
    _syncRouteListeners();
    _scheduleNotify();
  }

  List<ModalRoute<dynamic>> _pathOf(ModalRoute<dynamic> route) {
    final path = <ModalRoute<dynamic>>[route];
    var navigator = route.navigator;
    while (navigator != null) {
      final scope = navigator.context
          .getInheritedWidgetOfExactType<_GlassNavigationShellScope>();
      if (scope?.state != this) break;
      final parent = ModalRoute.of(navigator.context);
      if (parent == null || path.contains(parent)) break;
      // A sheet-local shell lives inside its presenting route. That route's
      // Navigator belongs to the app shell, so it is outside this boundary.
      final parentScope = parent.navigator?.context
          .getInheritedWidgetOfExactType<_GlassNavigationShellScope>();
      if (parentScope?.state != this) break;
      path.insert(0, parent);
      navigator = parent.navigator;
    }
    return path;
  }

  // Ancestors without a header still drive transitions and presentation handoff.
  // Share their subscriptions across every descendant registration.
  void _syncRouteListeners() {
    final routes = _routePaths.values.expand((path) => path).toSet();
    for (final route in _clockListeners.keys.toList()) {
      if (routes.contains(route)) continue;
      route.animation?.removeStatusListener(_clockListeners.remove(route)!);
      _gestureNotifiers.remove(route)?.removeListener(_scheduleNotify);
      if (identical(_clockRoute, route)) _clockRoute = null;
    }
    final animations = <Animation<double>>{
      for (final route in routes) ...[
        if (route.animation != null) route.animation!,
        if (route.secondaryAnimation != null) route.secondaryAnimation!,
      ],
    };
    for (final animation in _listened.toList()) {
      if (!animations.contains(animation)) _unlisten(animation);
    }
    for (final route in routes) {
      if (_clockListeners.containsKey(route)) continue;
      _listenTo(route.animation);
      _listenTo(route.secondaryAnimation);
      final listener =
          _clockListeners[route] = (status) => _onRouteStatus(route, status);
      route.animation?.addStatusListener(listener);
      final gestures = route.navigator?.userGestureInProgressNotifier;
      if (gestures != null) {
        _gestureNotifiers[route] = gestures;
        gestures.addListener(_scheduleNotify);
      }
    }
  }

  /// Removes [route] only if [owner] still owns its current registration.
  ///
  /// An omitted owner only releases a registration made without an owner.
  void unregister(ModalRoute<dynamic> route, {Object? owner}) {
    if (!identical(_registrationOwners[route], owner)) return;
    if (_registry.remove(route) == null) return;
    _registrationOwners.remove(route);
    if (identical(_sheetHold?.route, route)) _dropSheetHold();
    _routePaths.remove(route);
    _inactiveRoutes.remove(route);
    _syncRouteListeners();
    _scheduleNotify();
  }

  /// Starts [_clock] when [route]'s own transition does, if it needs one.
  ///
  /// A push or pop under a gesture is the swipe's — its rebound and commit
  /// are handled where the hold is. A run begins from wherever the chrome
  /// already is, so a pop that interrupts a push carries on from mid-morph
  /// rather than restarting at the far end.
  void _onRouteStatus(ModalRoute<dynamic> route, AnimationStatus status) {
    if (status != AnimationStatus.forward &&
        status != AnimationStatus.reverse) {
      return;
    }
    final navigation = _resolveNavigation();
    if (navigation == null ||
        navigation.driver != route ||
        navigation.to.routeDrivenTransitions) {
      return;
    }
    if (route.navigator?.userGestureInProgress ?? false) return;
    if (identical(_clockRoute, route) && _clockStatus == status) return;
    // Only a route on a simulation needs the clock; `createSimulation` is
    // the hook it overrides to run one.
    final forward = status == AnimationStatus.forward;
    if (route.createSimulation(forward: forward) == null) {
      if (identical(_clockRoute, route)) _clockRoute = null;
      return;
    }
    final current = identical(_clockRoute, route)
        ? _clockProgress()
        : route.animation?.value ?? 0.0;
    _clockRoute = route;
    _clockStatus = status;
    _clockFrom = forward ? current : 1.0 - current;
    _clock
      ..stop()
      ..duration =
          forward ? route.transitionDuration : route.reverseTransitionDuration;
    // A page-based Navigator starts a route inside the build phase, and
    // starting a controller notifies synchronously. Defer exactly as a tick
    // does; the frame in between reads the start value.
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      _clockPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_clockRoute, route)) return;
        _clockPending = false;
        _clock.forward(from: _clockFrom);
      });
    } else {
      _clockPending = false;
      _clock.forward(from: _clockFrom);
    }
  }

  /// Listens to both the value and the status of [animation].
  ///
  /// The status matters on its own: a transition's last value tick lands on
  /// 1.0 (or 0.0) *before* the controller reports itself completed, so a
  /// value-only listener never hears the frame where a rebounding back-swipe
  /// stops being a transition. [GlassNavPinnedState.settled] reads that
  /// status, so it needs the notification.
  void _listenTo(Animation<double>? animation) {
    if (animation == null || !_listened.add(animation)) return;
    animation.addListener(_onAnimationTick);
    animation.addStatusListener(_onAnimationStatus);
  }

  void _unlisten(Animation<double>? animation) {
    if (animation == null || !_listened.remove(animation)) return;
    animation.removeListener(_onAnimationTick);
    animation.removeStatusListener(_onAnimationStatus);
  }

  // A route wiring its secondary animation (`ProxyAnimation.parent=` inside
  // `didChangeNext`) notifies value listeners synchronously, and for a
  // page-based Navigator that runs inside `didUpdateWidget` — the build
  // phase — so the tick has to defer exactly as a status change does.
  void _onAnimationTick() => _scheduleNotify();

  void _onAnimationStatus(AnimationStatus status) {
    // Not while a finger is down: several routes' animations are listened to
    // at once, and one of them settling elsewhere must not drop the hold on
    // the swipe currently in progress.
    if (!_gestureActive &&
        (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed)) {
      _clearGestureHold();
    }
    _scheduleNotify();
  }

  /// Notifies listeners, deferring past build/layout when necessary.
  ///
  /// Registration happens during a descendant's build, so notifying inline
  /// would mutate the tree mid-frame. This mirrors the deferral used by the
  /// modal sheet morph's anchor.
  void _scheduleNotify() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      // Several routes can register in one frame (first build after a hot
      // reload, a popUntil); queue a single deferred notification for all.
      if (_notifyQueued) return;
      _notifyQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyQueued = false;
        if (mounted) _tick.notify();
      });
    } else {
      _tick.notify();
    }
  }

  // ---------------------------------------------------------------------------
  // Ordering
  // ---------------------------------------------------------------------------

  /// Resolves stack order only among routes owned by the same Navigator.
  /// The active leaf supplies content; the outermost transitioning route drives
  /// it. A settled parent delegates to its nested Navigator's transition.
  _GlassNavigationResolution? _resolveNavigation() {
    final children = <ModalRoute<dynamic>?, Set<ModalRoute<dynamic>>>{};
    for (final entry in _routePaths.entries) {
      if (_inactiveRoutes.contains(entry.key)) continue;
      final path = entry.value;
      if (!path.every(_participates)) continue;
      ModalRoute<dynamic>? parent;
      for (final route in path) {
        children.putIfAbsent(parent, () => {}).add(route);
        parent = route;
      }
    }

    _GlassNavigationResolution? resolve(ModalRoute<dynamic>? parent) {
      final candidates = children[parent];
      if (candidates == null || candidates.isEmpty) return null;
      // Parallel retained Navigators must declare their active branch. Never
      // compare their unrelated route animation values with one another.
      final navigator = candidates.last.navigator;
      final routes = candidates.where((r) => r.navigator == navigator).toList();
      final order = {for (var i = 0; i < routes.length; i++) routes[i]: i};
      routes.sort((a, b) {
        final coverage = _coverageOf(a).compareTo(_coverageOf(b));
        return coverage != 0 ? coverage : order[b]!.compareTo(order[a]!);
      });
      final top = routes.first;
      final below = routes.length > 1 ? routes[1] : null;
      final nested = resolve(top);
      final to = nested?.to ?? _registry[top];
      if (to == null) return null;
      final headerRoute = nested?.headerRoute ?? top;
      final path = [top, ...?nested?.path];
      final awaitingPush = below != null &&
          top.offstage &&
          top.animation?.status == AnimationStatus.completed &&
          _coverageOf(below) == 0;
      final transitioning = top.animation?.status == AnimationStatus.forward ||
          top.animation?.status == AnimationStatus.reverse ||
          (top.navigator?.userGestureInProgress ?? false) ||
          awaitingPush ||
          (!to.routeDrivenTransitions &&
              identical(_clockRoute, top) &&
              (_clockPending || _clock.isAnimating));
      if (nested != null && !transitioning) {
        return nested.withPath(path);
      }
      return _GlassNavigationResolution(
        driver: top,
        headerRoute: headerRoute,
        from: below == null
            ? _emptyChrome
            : resolve(below)?.to ?? _registry[below] ?? _emptyChrome,
        to: to,
        path: path,
        awaitingPush: awaitingPush,
      );
    }

    return resolve(null);
  }

  static const _emptyChrome = GlassNavBarRegistration(
    actions: <GlassBarItem>[],
    showsBackButton: false,
  );

  /// Whether [route] still contributes chrome this frame.
  ///
  /// `isActive` goes false the instant a route is popped, while its exit
  /// transition still has its full duration left to run. Filtering on that
  /// alone drops the outgoing route from the interpolation on the very first
  /// frame of a button-driven pop, snapping the chrome to the destination
  /// instead of morphing into it. A reversing route is still on screen and
  /// still owns chrome. The back-swipe never hit this, because a swipe only
  /// pops the route once the gesture commits. A replaced route remains completed
  /// and mounted until its replacement finishes entering; keep its endpoint
  /// until the old header unregisters at disposal.
  static bool _participates(ModalRoute<dynamic> route) =>
      route.isActive ||
      route.animation?.status == AnimationStatus.reverse ||
      route.animation?.status == AnimationStatus.completed;

  static double _coverageOf(ModalRoute<dynamic> route) =>
      route.secondaryAnimation?.value ?? 0.0;

  /// Whether [route] should leave its chrome to the shell this frame.
  ///
  /// True for every registered route while the shell is drawing, not only the
  /// topmost one: mid-transition the chrome is a blend of two routes' items,
  /// so the outgoing route has to keep its placeholder or its own buttons
  /// would slide out from underneath the pinned copy.
  ///
  /// False under a presentation, even while [presentingSheetItem] is set: the
  /// chrome as a whole has been handed back, and only that item's capsule is
  /// still the shell's.
  bool isHoisting(ModalRoute<dynamic> route) {
    if (!isActive || !_registry.containsKey(route)) return false;
    final navigation = _resolveNavigation();
    if (navigation == null) return false;
    return !navigation.path.any(_isPresentedOver);
  }

  /// The [GlassBarItem.sheet] whose capsule the shell is keeping hoisted for
  /// [route] through the sheet presented out of it, or null.
  ///
  /// Non-null only while [isHoisting] is false for the presentation: the rest
  /// of the chrome is the route's to draw, and the slot this item's group
  /// occupies stays the placeholder it already had, since the shell still
  /// draws that capsule and the morph has emptied it. It reads null again the
  /// frame the sheet is dismissed, when the whole chrome hoists back and the
  /// droplet is still on its way home. The instance is the one that was
  /// tapped, so a bar that rebuilds its items compares by `id`.
  GlassBarSheetItem? presentingSheetItem(ModalRoute<dynamic> route) {
    final hold = _sheetHold;
    if (hold == null || !identical(hold.route, route) || isHoisting(route)) {
      return null;
    }
    return hold.item;
  }

  /// Keeps [item]'s capsule hoisted through the sheet about to be presented
  /// out of [anchor].
  ///
  /// Called by the pinned host on the tap, before the item presents, so the
  /// hold is in place by the frame the sheet's route lands and the group is
  /// never unmounted from under the droplet. The hold is inert until a route
  /// is presented over [route] — the chrome stays hoisted exactly as it was —
  /// so the presenter may take as long as it needs to get there: measuring
  /// the sheet's content offscreen, awaiting a fetch. A tap that presents
  /// nothing leaves a hold that the next tap, presentation or unregistration
  /// of the route replaces. One whose presentation arrives with the anchor
  /// unemptied — a dialog, a sheet shown without the morph — is dropped at
  /// the end of that presentation's first frame, and the chrome hands back as
  /// for any other presentation. So is one whose presentation has gone.
  void holdForSheet(
    ModalRoute<dynamic> route,
    GlassBarSheetItem item,
    GlassMorphAnchor anchor,
  ) {
    _dropSheetHold();
    _sheetHold = _SheetHold(route: route, item: item, anchor: anchor);
    anchor.presentationChanges.addListener(_onSheetPresentationChanged);
  }

  /// Whether [hold] keeps its capsule through the presentation now over its
  /// route.
  ///
  /// True once the anchor has been emptied. Before that, the presenter empties
  /// the trigger during the sheet route's first build, and this may resolve
  /// earlier in the same frame — so the first presented-over resolve keeps
  /// the capsule and asks again at the end of the frame: still full then
  /// means no morph is coming out of it, and the hold is dropped.
  bool _sheetHoldClaimed(_SheetHold hold) {
    if (hold.anchor.isPresenting) return true;
    if (hold.presented) return false;
    hold.presented = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_sheetHold, hold) ||
          hold.anchor.isPresenting) {
        return;
      }
      _dropSheetHold();
      _scheduleNotify();
    });
    return true;
  }

  void _onSheetPresentationChanged() {
    final hold = _sheetHold;
    if (hold != null && !hold.anchor.isPresenting) _dropSheetHold();
    _scheduleNotify();
  }

  void _dropSheetHold() {
    final hold = _sheetHold;
    if (hold == null) return;
    hold.anchor.presentationChanges.removeListener(_onSheetPresentationChanged);
    _sheetHold = null;
  }

  /// Whether a route this shell cannot rank has been *presented* over [route].
  ///
  /// UIKit's push/present split is the one that matters here, and the two need
  /// opposite treatment. A pushed route slides the covered bar away with its
  /// page, which the shell mirrors by retreating the chrome on the covered
  /// route's `secondaryAnimation`. A presented one — a dialog, an action
  /// sheet, a modal sheet, a fullscreen dialog — comes up over the whole
  /// navigation stack with the bar inside it, and drives no exit transition to
  /// retreat on: `CupertinoRouteTransitionMixin.canTransitionTo` refuses a
  /// next route that is neither a `CupertinoRouteTransitionMixin` nor carries
  /// a `delegatedTransition`, and refuses a fullscreen dialog outright.
  ///
  /// Retreating would be the wrong answer even if there were an animation to
  /// retreat on. The chrome is not covered by a presentation, it is *under*
  /// one — still on screen behind a sheet, dimming with the barrier like the
  /// rest of the page. The shell cannot draw it there, because it draws above
  /// the [Navigator] the presentation was pushed into, so it gives the chrome
  /// back and the route renders it exactly where it renders when no shell is
  /// installed at all.
  ///
  /// `isCurrent` cannot answer this on its own: a route being popped is not
  /// current either, and it owns the chrome for the whole of its exit. What
  /// separates the two is whether any transition is running. Sheet-local
  /// shells also report their popup's lifetime: the covered page becomes
  /// current before the popup's reverse transition has finished.
  bool _isPresentedOver(ModalRoute<dynamic> route) =>
      (!route.isCurrent && _isAtRest(route)) ||
      _presentations.values.any((presentation) =>
          identical(presentation.navigator, route.navigator) &&
          (presentation.isCurrent || !presentation.isActive) &&
          presentation.animation?.status != AnimationStatus.dismissed);

  void _setPresentation(
    GlassNavigationShellState owner,
    PopupRoute<dynamic>? route,
  ) {
    if (!mounted) return;
    final previous = _presentations.remove(owner);
    previous?.animation?.removeStatusListener(_onPresentationStatus);
    if (route != null) {
      _presentations[owner] = route;
      route.animation?.addStatusListener(_onPresentationStatus);
    }
    _scheduleNotify();
  }

  void _onPresentationStatus(AnimationStatus status) => _scheduleNotify();

  /// Whether no transition involving [route] is in flight.
  static bool _isAtRest(ModalRoute<dynamic> route) =>
      (route.animation?.status ?? AnimationStatus.completed) ==
          AnimationStatus.completed &&
      (route.secondaryAnimation?.status ?? AnimationStatus.dismissed) ==
          AnimationStatus.dismissed &&
      !(route.navigator?.userGestureInProgress ?? false);

  /// The chrome progress to render, holding still under an active gesture.
  ///
  /// While the finger is down this returns the value the chrome had when the
  /// drag began, so nothing dissolves or cross-fades under a swipe that may
  /// yet be cancelled.
  ///
  /// Neither release path needs re-timing here. A commit is handed to
  /// [_commitExit], which replays the transition on its own clock; a cancelled
  /// swipe rebounds the route back to where the chrome was already held, so
  /// the live progress is the right answer on its own.
  double _holdForGesture(double progress, bool gesturing) {
    if (gesturing) {
      // The last value seen *before* the gesture, not the one on the frame it
      // was first observed: a drag has already travelled some distance by the
      // time the first frame resolves, and holding at that would bake the
      // jump it made in the meantime into the held value.
      _gestureHeldProgress ??= _ungesturedProgress ?? progress;
      _gestureActive = true;
      return _gestureHeldProgress!;
    }

    // Released. A commit is taken over by [_commitExit] and never reaches
    // here; a cancelled swipe rebounds to where it was held, so the live
    // progress is already the right answer.
    _gestureActive = false;
    _gestureHeldProgress = null;
    _ungesturedProgress = progress;
    return progress;
  }

  /// [_clock]'s run as chrome progress: 0 to 1 on a push, 1 to 0 on a pop.
  double _clockProgress() {
    final t = _clockPending ? _clockFrom : _clock.value;
    return _clockStatus == AnimationStatus.forward ? t : 1.0 - t;
  }

  /// Drops the gesture hold once a transition is over.
  ///
  /// Without this the next push would be re-timed against a release point
  /// from a swipe that finished long ago.
  void _clearGestureHold() {
    _gestureActive = false;
    _gestureHeldProgress = null;
  }

  // The first divergent routes identify the changed navigation boundary.
  // Root pushes/pops and inner pushes diverge within the SAME Navigator;
  // a retained tab switch diverges across sibling Navigators instead.
  static bool _changedBranch(
    _GlassNavigationResolution before,
    _GlassNavigationResolution after,
  ) {
    final count = before.path.length < after.path.length
        ? before.path.length
        : after.path.length;
    for (var i = 0; i < count; i++) {
      if (before.path[i] == after.path[i]) continue;
      final beforeNavigator = before.path[i].navigator;
      final afterNavigator = after.path[i].navigator;
      return beforeNavigator != null &&
          afterNavigator != null &&
          beforeNavigator != afterNavigator;
    }
    return false;
  }

  double get _branchProgress => _branchPendingProgress ?? _branchClock.value;

  void _clearBranchTransition() {
    _branchRevision++;
    _branchClock.stop();
    _branchPendingProgress = null;
    _branchFrom = _branchTo = null;
  }

  void _driveBranch(double target, double progress) {
    final revision = ++_branchRevision;
    _branchClock.stop();
    _branchTarget = target;
    _branchPendingProgress = progress;
    // Resolution happens in the host's build. Set the visible start progress
    // now, but start ticking only after registration/handoff finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _branchRevision) return;
      _branchPendingProgress = null;
      _branchClock.duration = widget.headerMotion.branchDuration;
      _branchClock.value = progress;
      if (target == 1) {
        _branchClock.forward();
      } else {
        _branchClock.reverse();
      }
    });
  }

  GlassNavPinnedState _resolveBranchTransition(
    _GlassNavigationResolution navigation,
    GlassNavPinnedState state,
  ) {
    final previous = _lastNavigation;
    _lastNavigation = navigation;
    // A real route transition or a presentation owns the header immediately.
    // Returning from either must not replay an old tab-selection snapshot.
    if (!state.settled ||
        state.coverage > 0 ||
        GlassAccessibilityData.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context)) {
      _clearBranchTransition();
      return state;
    }
    if (previous != null && _changedBranch(previous, navigation)) {
      final from = _branchFrom;
      final to = _branchTo;
      if (from != null &&
          to != null &&
          (navigation.headerRoute == from.headerRoute ||
              navigation.headerRoute == to.headerRoute)) {
        // Returning to an existing endpoint retraces the exact same frames.
        _driveBranch(
            navigation.headerRoute == to.headerRoute ? 1 : 0, _branchProgress);
      } else {
        final progress = _branchProgress;
        final showingFrom = from != null && progress < .5;
        _branchFrom = from == null
            ? previous
            : showingFrom
                ? from
                : to;
        _branchTo = navigation;
        // A third tab replaces the hidden endpoint rather than queuing it.
        _driveBranch(
            1,
            from == null
                ? 0
                : showingFrom
                    ? progress
                    : 1 - progress);
      }
    }
    final from = _branchFrom;
    final to = _branchTo;
    if (from == null || to == null) return state;
    if (_branchPendingProgress == null &&
        !_branchClock.isAnimating &&
        _branchClock.value == _branchTarget) {
      _clearBranchTransition();
      return state;
    }
    return GlassNavPinnedState(
      from: _registry[from.headerRoute] ?? from.to,
      to: _registry[to.headerRoute] ?? to.to,
      progress: _branchProgress,
      coverage: 0,
      settled: false,
      topRoute: navigation.headerRoute,
      transition: widget.effectTransition,
    );
  }

  /// The chrome to render right now, or null when nothing should be shown.
  GlassNavPinnedState? resolveState() {
    if (!isActive) {
      _lastNavigation = null;
      _clearBranchTransition();
      return null;
    }

    // A committed swipe plays from the frozen snapshot, not the registry: the
    // outgoing route unregisters when its pop finishes, which happens before
    // this animation does.
    final exiting = _commitExitSnapshot;
    if (exiting != null) {
      return GlassNavPinnedState(
        from: exiting.from,
        to: exiting.to,
        progress: _commitExitStart * (1.0 - _commitExit.value),
        coverage: exiting.coverage,
        settled: false,
        // A committed swipe is a pop by definition.
        popping: true,
        topRoute: exiting.topRoute,
        transition: exiting.transition,
        crossFade: widget.swipeCommitTransition ==
            GlassSwipeCommitTransition.crossFade,
      );
    }

    final navigation = _resolveNavigation();
    if (navigation == null) {
      _lastNavigation = null;
      _clearBranchTransition();
      return null;
    }
    final driver = navigation.driver;
    final headerRoute = navigation.headerRoute;
    final from = navigation.from;
    final to = navigation.to;

    // Nothing drawn above the `Navigator` can be underneath a route presented
    // into it, so the shell stands down and the registrants take their chrome
    // back for as long as one is up — all but the capsule a sheet is morphing
    // out of, which stays up at rest on its own.
    if (navigation.path.any(_isPresentedOver)) {
      _lastNavigation = null;
      _clearBranchTransition();
      final hold = _sheetHold;
      if (hold == null ||
          !identical(hold.route, headerRoute) ||
          !_sheetHoldClaimed(hold)) {
        return null;
      }
      return GlassNavPinnedState(
        from: from,
        to: to,
        progress: 1.0,
        coverage: 0.0,
        settled: true,
        topRoute: headerRoute,
        transition: widget.effectTransition,
        presenting: hold.item,
      );
    }
    // A hold is for one presentation; with that gone, so is the hold. Dropped
    // here rather than on the route's pop so a trigger unmounted while the
    // sheet was up cannot leave one behind. One still waiting for its
    // presentation to arrive is left alone.
    if (_sheetHold?.presented ?? false) _dropSheetHold();

    // Progress of the top route's own entrance: 1 at rest, 0 when it has just
    // been pushed, and scrubbed by the interactive back-swipe during a pop.
    // A completed route is at 1 whatever its controller last reported — a
    // simulation stops inside a tolerance of its end, not on it.
    final status = driver.animation?.status ?? AnimationStatus.completed;
    var progress = status == AnimationStatus.completed
        ? 1.0
        : driver.animation?.value ?? 1.0;

    // The first offstage build can precede the real push controller.
    final awaitingPush = navigation.awaitingPush;
    if (awaitingPush) progress = 0.0;

    // Retreat only when something *unregistered* sits above the top route —
    // a plain route or a modal sheet. `isCurrent` is what distinguishes that
    // from a pop still unwinding this route's secondaryAnimation: anything
    // registered above would have sorted above it instead, so a non-current
    // top route is covered by something this shell doesn't manage.
    final coverage = navigation.path.fold<double>(0, (value, route) {
      final covered = route.isCurrent ? 0.0 : _coverageOf(route);
      return covered > value ? covered : value;
    });

    // True for the whole of a swipe *and* the commit or rebound that follows
    // it: Cupertino only calls `didStopUserGesture` from a status listener
    // once that animation has finished.
    final userGesture = driver.navigator?.userGestureInProgress ?? false;

    // A push or pop under no gesture plays on [_clock], started by
    // [_onRouteStatus]. The run outlives the route if the route's own value
    // got there first; the chrome is not settled until it has.
    final running =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    final routeDriven = to.routeDrivenTransitions;
    final clocked = !routeDriven &&
        identical(_clockRoute, driver) &&
        !userGesture &&
        (running || _clockPending || _clock.isAnimating);
    if (clocked) progress = _clockProgress();

    // Whether the chrome may be tapped. Deliberately not derived from
    // `progress`: a pop starts at 1.0 and a back-swipe sits there until the
    // finger moves, so by value alone a transition that is very much running
    // looks finished. The controller's status and the navigator's gesture flag
    // are what actually tell the two apart, and `isCurrent` covers a route
    // that something unregistered has been pushed over.
    final settled = !awaitingPush &&
        navigation.path.every((route) => route.isCurrent) &&
        status == AnimationStatus.completed &&
        !userGesture &&
        !(clocked && (_clockPending || _clock.isAnimating));

    // Whether the finger is still down with the pop not yet committed — which
    // is narrower than [userGesture], and is what the chrome hold needs.
    // Holding on the broader flag kept the chrome frozen for the whole commit
    // animation and then snapped it at the end, with no transition played.
    //
    // The route is the witness: committing pops it immediately, so `isActive`
    // goes false the moment the finger lifts on a commit, while a cancelled
    // swipe leaves it active through the rebound — exactly when the chrome
    // should still be holding.
    final gesturing = userGesture && driver.isActive;

    // The frame the swipe commits: the finger has lifted and the route is
    // already popped. Freeze what the chrome looked like and hand it to
    // [_commitExit], which plays it out on its own clock.
    //
    // The held value has to be read before [_holdForGesture] runs, because
    // releasing clears it — and the held value is exactly where the chrome
    // must start from, not the live progress the drag happened to reach.
    final committing =
        !routeDriven && _gestureActive && !gesturing && !driver.isActive;
    final heldAtCommit = _gestureHeldProgress ?? progress;

    // A pop plays the same forward choreography toward the other target, not
    // the push in reverse — the host mirrors the clock and swaps the roles.
    // The gesture flag matters as much as the status: a back-swipe holds the
    // controller at whatever value the finger dictates without ever entering
    // AnimationStatus.reverse.
    final popping = !routeDriven &&
        !settled &&
        (status == AnimationStatus.reverse ||
            userGesture ||
            (clocked && _clockStatus == AnimationStatus.reverse));

    final state = GlassNavPinnedState(
      from: from,
      to: to,
      progress: routeDriven
          ? progress.clamp(0.0, 1.0)
          : committing
              ? heldAtCommit.clamp(0.0, 1.0)
              : _holdForGesture(progress, gesturing).clamp(0.0, 1.0),
      coverage: coverage.clamp(0.0, 1.0),
      settled: settled,
      popping: popping,
      topRoute: headerRoute,
      transition: widget.effectTransition,
      holdForSheet: (item, anchor) => holdForSheet(headerRoute, item, anchor),
    );

    if (committing) {
      _gestureActive = false;
      _gestureHeldProgress = null;
      _commitExitStart = state.progress;
      _commitExitSnapshot = state;
      // Deferred: this runs inside [_tick]'s own ListenableBuilder, and
      // starting a controller notifies its listeners synchronously — which
      // would mark that builder dirty in the middle of its own build. The
      // controller rests at 0 until then, so the frame in between holds the
      // snapshot rather than showing a gap.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _commitExitSnapshot != null) {
          _commitExit.forward(from: 0.0);
        }
      });
    }
    return _resolveBranchTransition(navigation, state);
  }

  @override
  void dispose() {
    _presentationParent?._setPresentation(this, null);
    for (final route in _presentations.values) {
      route.animation?.removeStatusListener(_onPresentationStatus);
    }
    _presentations.clear();
    VerticalBarRegions.instance.removeListener(_onVerticalBarRegions);
    VerticalBarRegions.instance.edge.removeListener(_onVerticalBarRegions);
    for (final animation in _listened) {
      animation.removeListener(_onAnimationTick);
      animation.removeStatusListener(_onAnimationStatus);
    }
    _listened.clear();
    for (final entry in _clockListeners.entries) {
      entry.key.animation?.removeStatusListener(entry.value);
    }
    _clockListeners.clear();
    for (final gestures in _gestureNotifiers.values) {
      gestures.removeListener(_scheduleNotify);
    }
    _gestureNotifiers.clear();
    _dropSheetHold();
    _commitExit.dispose();
    _clock.dispose();
    _branchClock.dispose();
    _tick.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Vertical bar strip
  // ---------------------------------------------------------------------------

  /// The strip resolved by the last build, or null.
  GlassVerticalBarData? _verticalBar;

  /// The strip this shell resolved for the screen, or null where its bars are
  /// horizontal.
  ///
  /// A subtree can keep its own bars horizontal under it with
  /// [GlassVerticalBar.disabled]; [GlassVerticalBar.maybeOf] answers for a
  /// particular context.
  GlassVerticalBarData? get verticalBar => _verticalBar;

  /// Height each bar at the bottom of the strip takes, keyed by its owner.
  final Map<Object, double> _verticalBarBottom = <Object, double>{};

  /// How much of the vertical bar strip, measured from the bottom of the
  /// screen, the bars stacked there take — a tab bar, a toolbar.
  ///
  /// The pinned chrome is laid out in what is left above it, and overflows
  /// into a ••• menu where that is not enough. Zero with nothing reserved.
  double get verticalBarBottom => _verticalBarBottom.values
      .fold(0.0, (max, extent) => extent > max ? extent : max);

  /// Reserves [extent] of the strip's bottom for [owner], replacing any
  /// earlier reservation it made.
  ///
  /// Called by the package's tab bar and toolbar while they lay out in the
  /// strip. A bar drawn there by the app reserves its own height, plus the
  /// strip's [GlassVerticalBarData.bottom], the same way.
  void reserveVerticalBarBottom(Object owner, double extent) {
    if (_verticalBarBottom[owner] == extent) return;
    _verticalBarBottom[owner] = extent;
    _scheduleNotify();
  }

  /// Drops [owner]'s reservation.
  void releaseVerticalBarBottom(Object owner) {
    if (_verticalBarBottom.remove(owner) != null) _scheduleNotify();
  }

  void _onVerticalBarRegions() => setState(() {});

  /// The strip this shell's bars lay out in, or null where they are
  /// horizontal.
  ///
  /// Read from the insets the shell itself sees, which is above any [SafeArea]
  /// a page puts around its content, and from the regions UIKit reserves for
  /// the status cluster and the camera, which Flutter does not report on iOS
  /// yet. See [GlassVerticalBar.resolve].
  GlassVerticalBarData? _resolveVerticalBar(BuildContext context) {
    if (!isActive ||
        widget.verticalBarBehavior == GlassVerticalBarBehavior.disabled) {
      return null;
    }
    final bar = GlassVerticalBar.resolve(
      viewPadding: MediaQuery.viewPaddingOf(context),
      size: MediaQuery.sizeOf(context),
      platform: defaultTargetPlatform,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      displayFeatures: [
        ...MediaQuery.displayFeaturesOf(context),
        ...VerticalBarRegions.instance.value,
      ],
      systemEdge: VerticalBarRegions.instance.edge.value,
      compression: widget.verticalBarCompression,
    );
    // Followed on iOS whether or not a strip is up yet: where UIKit leaves the
    // strip to the app, its edge is the only sign of it.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      VerticalBarRegions.instance.observe();
    }
    return bar;
  }

  /// [child] under the media query the app should see.
  ///
  /// The regions UIKit reserves join [MediaQueryData.displayFeatures], which
  /// is where Flutter will report them once it does on iOS
  /// (flutter/flutter#193025): the status cluster and the camera as cutouts,
  /// and the fold of a half-folded display as a hinge, which
  /// [DisplayFeatureSubScreen] keeps dialogs and sheets to one side of. And
  /// for a strip UIKit leaves to the app, its width joins the insets on its
  /// side, so the content keeps clear of it as it does of a strip the system
  /// insets for.
  Widget _mediaQueryFor(
    BuildContext context,
    GlassVerticalBarData? bar,
    Widget child,
  ) {
    final regions = VerticalBarRegions.instance.value;
    final insetsStrip = bar != null && !bar.systemInset;
    if (regions.isEmpty && !insetsStrip) return child;
    var data = MediaQuery.of(context);
    if (regions.isNotEmpty) {
      final reported = {for (final f in data.displayFeatures) f.bounds};
      data = data.copyWith(displayFeatures: [
        ...data.displayFeatures,
        for (final region in regions)
          if (!reported.contains(region.bounds)) region,
      ]);
    }
    if (insetsStrip) {
      final ltr = (Directionality.maybeOf(context) ?? TextDirection.ltr) ==
          TextDirection.ltr;
      final onLeft = (bar.edge == GlassVerticalBarEdge.leading) == ltr;
      EdgeInsets add(EdgeInsets insets) => insets.copyWith(
            left: onLeft ? insets.left + bar.width : insets.left,
            right: onLeft ? insets.right : insets.right + bar.width,
          );
      data = data.copyWith(
        padding: add(data.padding),
        viewPadding: add(data.viewPadding),
      );
    }
    return MediaQuery(data: data, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final verticalBar = _verticalBar = _resolveVerticalBar(context);
    return _GlassNavigationShellScope(
      state: this,
      child: Stack(
        children: [
          GlassVerticalBar(
            data: verticalBar,
            child: NotificationListener<NavigationNotification>(
              onNotification: (_) {
                // A modal on an ancestor Navigator changes isCurrent without
                // driving the covered route's secondary animation. Its leaf
                // header may not rebuild either, so refresh the handover from
                // Navigator history notifications as well as animation ticks.
                _scheduleNotify();
                // Preserve notifications used by nested navigation/back handling.
                return false;
              },
              child: _mediaQueryFor(context, verticalBar, widget.child),
            ),
          ),
          // The chrome gets an Overlay of its own because it deliberately sits
          // above the app's Navigator, and therefore outside the Navigator's
          // Overlay — a GlassBarItem.menu portals to the root overlay, and up
          // here there would otherwise be none to find. This one is full-screen
          // and origin-aligned, so the menu's global-coordinate morph lands on
          // its trigger exactly as it does inside a route, and its dismiss
          // barrier covers the page below. It is a *sibling* of the Navigator,
          // not an ancestor, so nothing inside the app resolves its root
          // overlay to this one.
          if (widget.enabled)
            Overlay.wrap(
              child: ListenableBuilder(
                listenable: _tick,
                builder: (context, _) {
                  final state = resolveState();
                  if (state == null) return const SizedBox.shrink();
                  return GlassVerticalBar(
                    data: verticalBar,
                    child: _GlassHeaderMotionScope(
                      transitioning: !state.settled,
                      motion: widget.headerMotion,
                      child: GlassNavPinnedHost(state: state),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassHeaderMotionScope extends InheritedWidget {
  const _GlassHeaderMotionScope({
    required this.transitioning,
    required this.motion,
    required super.child,
  });

  final bool transitioning;
  final GlassHeaderMotion motion;

  @override
  bool updateShouldNotify(_GlassHeaderMotionScope oldWidget) =>
      transitioning != oldWidget.transitioning || motion != oldWidget.motion;
}

/// Exposes the shell state to descendant registrants.
class _GlassNavigationShellScope extends InheritedWidget {
  const _GlassNavigationShellScope({
    required this.state,
    required super.child,
  });

  final GlassNavigationShellState state;

  @override
  bool updateShouldNotify(_GlassNavigationShellScope oldWidget) =>
      state != oldWidget.state;
}

/// A capsule kept hoisted through the sheet presented out of it.
class _SheetHold {
  _SheetHold({
    required this.route,
    required this.item,
    required this.anchor,
  });

  /// The route whose chrome the capsule belongs to.
  final ModalRoute<dynamic> route;

  /// The item that was tapped.
  final GlassBarSheetItem item;

  /// The hoisted capsule's anchor, whose [GlassMorphAnchor.isPresenting] is
  /// the hold's lifetime.
  final GlassMorphAnchor anchor;

  /// Whether a route has been presented over [route] since the tap.
  ///
  /// Until then the hold is waiting for the sheet to arrive and is not
  /// dropped by a resolve that finds nothing presented over the route.
  bool presented = false;
}

/// A [ChangeNotifier] whose notification is callable by its owner.
class _TickNotifier extends ChangeNotifier {
  /// Notifies listeners that the pinned chrome may have changed.
  void notify() => notifyListeners();
}

/// Content ownership is separate from the route driving its presentation.
class _GlassNavigationResolution {
  const _GlassNavigationResolution({
    required this.driver,
    required this.headerRoute,
    required this.from,
    required this.to,
    required this.path,
    this.awaitingPush = false,
  });

  final ModalRoute<dynamic> driver;
  final ModalRoute<dynamic> headerRoute;
  final GlassNavBarRegistration from, to;
  final List<ModalRoute<dynamic>> path;
  final bool awaitingPush;

  _GlassNavigationResolution withPath(List<ModalRoute<dynamic>> ancestors) =>
      _GlassNavigationResolution(
        driver: driver,
        headerRoute: headerRoute,
        from: from,
        to: to,
        path: ancestors,
        awaitingPush: awaitingPush,
      );
}
