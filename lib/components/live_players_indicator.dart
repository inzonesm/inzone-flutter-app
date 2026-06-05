import 'package:flutter/material.dart';
import 'package:inzone/services/community_game_service.dart';

/// Shared green used for the "live players" dot across the hub tile and the
/// home-feed card.
const Color kLivePlayersGreen = Color(0xFF34D399);

/// Fetches a community game's live player count (open sessions) and rebuilds as
/// it resolves, exposing a pulse animation for the "live" dot.
///
/// While the count is loading or zero it renders [idle] (nothing by default);
/// once at least one person is playing it renders [builder] with the count and
/// the pulse animation. Each surface supplies its own visual so the same data +
/// animation can back both the corner pill (over an image) and the inline
/// subtitle on the feed card.
class LivePlayersIndicator extends StatefulWidget {
  final String gameId;
  final Widget Function(
    BuildContext context,
    int count,
    Animation<double> pulse,
  ) builder;
  final WidgetBuilder? idle;

  const LivePlayersIndicator({
    super.key,
    required this.gameId,
    required this.builder,
    this.idle,
  });

  @override
  State<LivePlayersIndicator> createState() => _LivePlayersIndicatorState();
}

class _LivePlayersIndicatorState extends State<LivePlayersIndicator>
    with SingleTickerProviderStateMixin {
  int? _count;
  late final AnimationController _pulse;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    // Create the controller eagerly here, NOT via a lazy `late` initializer:
    // the badge is hidden at zero players, so build() may never read _pulse —
    // a lazy field would then first-initialize (and create a Ticker) inside
    // dispose(), i.e. during teardown, which trips framework lifecycle asserts.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.45, end: 1).animate(_pulse);
    _load();
  }

  @override
  void didUpdateWidget(covariant LivePlayersIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // List/grid tiles get recycled across games as the user scrolls — refetch
    // when this slot is rebound to a different game.
    if (oldWidget.gameId != widget.gameId) {
      _count = null;
      _load();
    }
  }

  Future<void> _load() async {
    final n = await CommunityGameService.fetchLivePlayerCount(widget.gameId);
    if (mounted) setState(() => _count = n);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    if (count == null || count <= 0) {
      return widget.idle?.call(context) ?? const SizedBox.shrink();
    }
    return widget.builder(context, count, _pulseOpacity);
  }
}
