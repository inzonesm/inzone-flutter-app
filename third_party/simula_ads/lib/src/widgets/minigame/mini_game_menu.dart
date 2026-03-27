import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/types.dart';
import '../../widgets/simula_provider.dart';
import '../../utils/webview_security.dart';
import 'assets.dart' as assets;
import 'game_grid.dart';
import 'game_iframe.dart';

const int _minPlayableHeight = 500;
const Color _defaultPlayableBorderColor = Color(0xFF262626);

class MiniGameMenu extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<MiniGameCompletion>? onGameEnd;
  final VoidCallback? onCharacterTap;
  final String charName;
  final String charID;
  final String? charImage;
  final List<Message> messages;
  final String? charDesc;
  final int maxGamesToShow;
  final bool delegateChar;
  final MiniGameTheme? theme;
  final String? initialGameId;

  /// Custom message to show when privacy consent is not granted.
  /// If not provided, a default message will be shown.
  final String? consentRequiredMessage;

  const MiniGameMenu({
    super.key,
    required this.isOpen,
    required this.onClose,
    this.onGameEnd,
    this.onCharacterTap,
    required this.charName,
    required this.charID,
    this.charImage,
    this.messages = const [],
    this.charDesc,
    this.maxGamesToShow = 6,
    this.delegateChar = true,
    this.theme,
    this.initialGameId,
    this.consentRequiredMessage,
  });

  @override
  State<MiniGameMenu> createState() => _MiniGameMenuState();
}

class _MiniGameMenuState extends State<MiniGameMenu> {
  String? _selectedGameId;
  GameData? _lastPlayedGame;
  String? _lastGameOverText;
  DateTime? _gameSessionStartedAt;
  bool _hasAttemptedInitialGameLaunch = false;
  List<GameData> _games = [];
  List<GameData> _filteredGames = [];
  bool _catalogLoading = true;
  bool _catalogError = false;
  bool _adFetched = false;
  String? _adIframeUrl;
  String? _currentAdId;
  String? _menuId; // Store menu_id from catalog response
  double? _resizedHeight; // Store resized height from game iframe
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  String?
      _previousAdIframeUrl; // Track previous ad overlay state for status bar
  bool _isDialogShowing = false; // Track if dialog is currently showing
  StateSetter?
      _dialogStateSetter; // Store dialog's StateSetter to trigger rebuilds

  int _gameOverTextSignalScore(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final lower = text.toLowerCase();
    int score = 0;

    if (RegExp(r'\bscore\s*[:=-]?\s*\d+').hasMatch(lower)) score += 4;
    if (RegExp(r'\blevel\s*[:=-]?\s*\d+').hasMatch(lower)) score += 3;
    if (RegExp(r'\bturns?\s*[:=-]?\s*\d+').hasMatch(lower)) score += 3;
    if (RegExp(r'\bcoins?\s*[:=-]?\s*\d+').hasMatch(lower)) score += 3;
    if (RegExp(r'\bdistance\s*[:=-]?\s*\d+').hasMatch(lower)) score += 3;
    if (lower.contains('action: game_end')) score += 2;
    if (lower.contains('game over') || lower.contains('final score')) score += 2;

    score += (text.length / 120).floor();
    return score;
  }

  String? _pickBetterGameOverText(String? current, String? incoming) {
    final incomingTrimmed = incoming?.trim();
    if (incomingTrimmed == null || incomingTrimmed.isEmpty) return current;
    if (current == null || current.trim().isEmpty) return incomingTrimmed;

    final currentScore = _gameOverTextSignalScore(current);
    final incomingScore = _gameOverTextSignalScore(incomingTrimmed);
    return incomingScore >= currentScore ? incomingTrimmed : current;
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      // Defer setState to avoid calling it during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSearchFocused = _searchFocusNode.hasFocus;
          });
        }
      });
    });
    if (widget.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isOpen) {
          _showDialog();
        }
      });
      _loadCatalog();
    }
  }

  @override
  void didUpdateWidget(MiniGameMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGameId != widget.initialGameId) {
      _hasAttemptedInitialGameLaunch = false;
      if (widget.isOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _tryLaunchInitialGame();
          }
        });
      }
    }
    if (widget.isOpen && !oldWidget.isOpen) {
      if (!_isDialogShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isOpen && !_isDialogShowing) {
            _showDialog();
          }
        });
      }
      _loadCatalog();
    }
    if (!widget.isOpen && oldWidget.isOpen) {
      if (_isDialogShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isDialogShowing) {
            _dismissDialog();
          }
        });
      }
      // Reset search when menu closes - defer to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchController.clear();
          _filterGames('');
          _searchFocusNode.unfocus();
          setState(() {
            _isSearchFocused = false;
          });
        }
      });
    }

    final characterHeaderChanged = oldWidget.charID != widget.charID ||
        oldWidget.charName != widget.charName ||
        oldWidget.charImage != widget.charImage;

    if (characterHeaderChanged && _isDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isDialogShowing) {
          _dialogStateSetter?.call(() {});
        }
      });
    }

    // Handle status bar for ad overlay
    final previousAdUrl = _previousAdIframeUrl;
    _previousAdIframeUrl = _adIframeUrl;

    if (_adIframeUrl != null && previousAdUrl == null) {
      // Ad overlay just opened - keep system UI visible to avoid dynamic island overlap
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    } else if (_adIframeUrl == null && previousAdUrl != null) {
      // Ad overlay just closed - restore status bar
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void _loadCatalog() async {
    setState(() {
      _catalogLoading = true;
      _catalogError = false;
    });

    try {
      final notifier = Provider.of<SimulaNotifier>(context, listen: false);
      final catalogResponse = await notifier.apiClient.fetchCatalog();
      setState(() {
        _games = catalogResponse.games;
        _filteredGames = catalogResponse.games;
        _menuId = catalogResponse.menuId;
        _catalogLoading = false;
      });
      _tryLaunchInitialGame();
      // Trigger dialog rebuild if it's showing
      _dialogStateSetter?.call(() {});
    } catch (error) {
      setState(() {
        _catalogError = true;
        _games = [];
        _filteredGames = [];
        _menuId = null;
        _catalogLoading = false;
      });
      // Trigger dialog rebuild if it's showing
      _dialogStateSetter?.call(() {});
    }
  }

  void _filterGames(String query) {
    // Defer state updates to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (query.isEmpty) {
        setState(() {
          _filteredGames = _games;
        });
        // Trigger dialog rebuild if it's showing
        _dialogStateSetter?.call(() {});
      } else {
        setState(() {
          _filteredGames = _games
              .where((game) =>
                  game.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
        // Trigger dialog rebuild if it's showing
        _dialogStateSetter?.call(() {});
      }
    });
  }

  @override
  void dispose() {
    // Restore status bar when disposing
    if (_adIframeUrl != null) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
    // Dismiss dialog if still showing
    if (_isDialogShowing) {
      _dismissDialog();
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleGameSelect(String gameId) {
    final selectedGame = _games.where((game) => game.id == gameId).firstOrNull;
    setState(() {
      _selectedGameId = gameId;
      _lastPlayedGame = selectedGame;
      _lastGameOverText = null;
      _gameSessionStartedAt = DateTime.now();
      _adFetched = false;
      _currentAdId = null;
      _resizedHeight = null; // Reset resized height when selecting a new game
    });
    // Close the menu modal (but keep the widget mounted for the iframe)
    widget.onClose();
  }

  void _tryLaunchInitialGame() {
    if (!widget.isOpen || _catalogLoading || _games.isEmpty) return;
    if (_hasAttemptedInitialGameLaunch) return;

    final initialGameId = widget.initialGameId?.trim();
    if (initialGameId == null || initialGameId.isEmpty) return;

    _hasAttemptedInitialGameLaunch = true;
    final game = _games.where((item) => item.id == initialGameId).firstOrNull;
    if (game != null) {
      _handleGameSelect(game.id);
    }
  }

  bool _inferPlayedLikely() {
    final startedAt = _gameSessionStartedAt;
    if (startedAt == null) return false;
    final elapsed = DateTime.now().difference(startedAt);
    return elapsed.inSeconds >= 8;
  }

  void _handleAdIdReceived(String adId) {
    setState(() {
      _currentAdId = adId;
    });
  }

  void _handleIframeClose(double? resizedHeight) async {
    // Store the resized height for use in ad overlay
    _resizedHeight = resizedHeight;
    if (!_adFetched) {
      // Make API request and fetch / display ad.html here
      if (_currentAdId != null) {
        try {
          final notifier = Provider.of<SimulaNotifier>(context, listen: false);
          final iframeUrl =
              await notifier.apiClient.fetchAdForMinigame(_currentAdId!);
          if (iframeUrl != null) {
            // Update SystemUI based on playableHeight
            final screenSize = MediaQuery.of(context).size;
            final (_, isBottomSheet) = _calculateAdHeight(screenSize);

            if (!isBottomSheet) {
              // Keep system UI visible to avoid dynamic island overlap
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.edgeToEdge,
                overlays: SystemUiOverlay.values,
              );
            } else {
              // Show status bar for bottom sheet ad overlay
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.edgeToEdge,
                overlays: SystemUiOverlay.values,
              );
            }
            setState(() {
              _adIframeUrl = iframeUrl;
              _adFetched = true;
              _selectedGameId = null; // Close game iframe
            });
            return; // Don't continue to close game iframe again
          }
        } catch (error) {
          // If ad fetch fails, just close without showing ad
        }
      }
      // If no ad to fetch or fetch failed, just close the game iframe
      setState(() {
        _selectedGameId = null;
      });
      widget.onGameEnd?.call(MiniGameCompletion(
        game: _lastPlayedGame,
        playedLikely: _inferPlayedLikely(),
        gameOverText: _lastGameOverText,
      ));
    } else {
      // If ad has already been fetched, just close so we don't double count impressions
      setState(() {
        _selectedGameId = null;
      });
      widget.onGameEnd?.call(MiniGameCompletion(
        game: _lastPlayedGame,
        playedLikely: _inferPlayedLikely(),
        gameOverText: _lastGameOverText,
      ));
    }
  }

  void _handleAdIframeClose() {
    // Restore status bar when closing ad overlay
    final screenSize = MediaQuery.of(context).size;
    final (_, isBottomSheet) = _calculateAdHeight(screenSize);

    // Only restore status bar if it was full screen (not bottom sheet)
    if (!isBottomSheet) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
    setState(() {
      _adIframeUrl = null;
      // Keep _adFetched as true so we don't show another ad
    });
    widget.onGameEnd?.call(MiniGameCompletion(
      game: _lastPlayedGame,
      playedLikely: _inferPlayedLikely(),
      gameOverText: _lastGameOverText,
    ));
  }

  String _getInitials(String name) {
    return name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .join('')
        .toUpperCase()
        .substring(0, name.split(' ').length > 1 ? 2 : 1);
  }

  void _showDialog() {
    if (!mounted || _isDialogShowing) return;

    setState(() {
      _isDialogShowing = true;
    });

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss menu',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Store setDialogState for rebuilding dialog content
            _dialogStateSetter = setDialogState;
            return _buildMenuModalContent();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ).then((_) {
      if (mounted) {
        // Dialog was dismissed (by barrier tap or back button)
        setState(() {
          _isDialogShowing = false;
          _dialogStateSetter = null;
        });
        // Call onClose to update parent's isOpen state
        // Only call if isOpen is still true (X button already calls onClose directly)
        if (widget.isOpen) {
          widget.onClose();
        }
      }
    });
  }

  void _dismissDialog() {
    if (mounted && _isDialogShowing && Navigator.of(context).canPop()) {
      setState(() {
        _isDialogShowing = false;
        _dialogStateSetter = null;
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen && _selectedGameId == null && _adIframeUrl == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Game Iframe
        if (_selectedGameId != null)
          Positioned.fill(
            child: GameIframe(
              gameId: _selectedGameId!,
              onCharacterTap: widget.onCharacterTap,
              onGameOverText: (text) {
                _lastGameOverText =
                    _pickBetterGameOverText(_lastGameOverText, text);
              },
              charID: widget.charID,
              charName: widget.charName,
              charImage: widget.charImage,
              charDesc: widget.charDesc,
              messages: widget.messages,
              delegateChar: widget.delegateChar,
              onClose: _handleIframeClose,
              onAdIdReceived: _handleAdIdReceived,
              menuId: _menuId,
              playableHeight: widget.theme?.playableHeight,
              playableBorderColor: widget.theme?.playableBorderColor,
            ),
          ),

        // Ad Iframe
        if (_adIframeUrl != null)
          Positioned.fill(
            child: _buildAdOverlay(),
          ),
      ],
    );
  }

  /// Calculate container height based on playableHeight prop
  /// - double <= 1.0: percentage of screen height (e.g., 0.8 = 80%, 1.0 = 100%)
  /// - double > 1.0: pixel value (e.g., 600.0 = 600px)
  /// - null: full screen
  /// Minimum height is enforced at 500px - if calculated height is below 500, defaults to 500
  (double containerHeight, bool isBottomSheet) _calculateAdHeight(
      Size screenSize) {
    final playableHeight = widget.theme?.playableHeight;

    // If no playableHeight or null, use full screen
    if (playableHeight == null) {
      return (screenSize.height, false);
    }

    double calculatedHeight;

    if (playableHeight is double) {
      if (playableHeight <= 1.0) {
        // Percentage value (e.g., 0.8 = 80%, 1.0 = 100%)
        final percentageValue = playableHeight;

        // Treat > 0.95 or == 1.0 as full screen (no bottom sheet UI)
        if (percentageValue > 0.95 || percentageValue == 1.0) {
          return (screenSize.height, false);
        }

        // Calculate height from percentage, then enforce minimum of 500px
        calculatedHeight = screenSize.height * percentageValue;
        if (calculatedHeight < _minPlayableHeight) {
          calculatedHeight = _minPlayableHeight.toDouble();
        }
        // Ensure we don't exceed screen height
        calculatedHeight = calculatedHeight.clamp(
            _minPlayableHeight.toDouble(), screenSize.height);
      } else {
        // Pixel value (e.g., 600.0 = 600px) - must be > 1.0
        // If the pixel value is >= screen height, treat as full screen
        if (playableHeight >= screenSize.height) {
          return (screenSize.height, false);
        }

        // If below minimum, default to minimum height
        calculatedHeight = playableHeight < _minPlayableHeight
            ? _minPlayableHeight.toDouble()
            : playableHeight;
        // Ensure we don't exceed screen height
        calculatedHeight = calculatedHeight.clamp(
            _minPlayableHeight.toDouble(), screenSize.height);
      }
    } else {
      // Invalid value, use full screen
      return (screenSize.height, false);
    }

    return (calculatedHeight, true);
  }

  Widget _buildAdOverlay() {
    final screenSize = MediaQuery.of(context).size;
    final (calculatedHeight, isBottomSheet) = _calculateAdHeight(screenSize);
    // Use resized height if available, otherwise use calculated height
    final containerHeight = _resizedHeight ?? calculatedHeight;
    final playableBorderColor =
        widget.theme?.playableBorderColor ?? _defaultPlayableBorderColor;

    final adController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            // Allow initial load of iframe URL
            if (_adIframeUrl != null && url == _adIframeUrl) {
              return NavigationDecision.navigate;
            }

            // Allow special/internal URLs
            for (final scheme in allowedSpecialSchemes) {
              if (url.startsWith(scheme)) {
                return NavigationDecision.navigate;
              }
            }

            // Block javascript: URLs
            if (url.startsWith('javascript:')) {
              return NavigationDecision.prevent;
            }

            // Check if origin is allowed - open externally for better UX
            if (isOriginAllowed(url)) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                  .catchError((_) => false);
              return NavigationDecision.prevent;
            }

            // For any other navigation, open externally
            if (url.isNotEmpty && url != _adIframeUrl) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                  .catchError((_) => false);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_adIframeUrl!));

    // Calculate close button position
    // If bottom sheet, position at top of container (screenHeight - containerHeight + offset)
    // If full screen, position below the safe area (dynamic island)
    final safeTop = MediaQuery.of(context).padding.top;
    final fullScreenButtonTop = safeTop + 8.0;
    final closeButtonTop =
        isBottomSheet ? screenSize.height - containerHeight + 60 : fullScreenButtonTop;
    final touchBlockerTop =
        isBottomSheet ? screenSize.height - containerHeight + 8 : safeTop;

    if (isBottomSheet) {
      const sheetRadius = 16.0;
      return Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(sheetRadius),
            child: Container(
              height: containerHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: playableBorderColor,
                borderRadius: BorderRadius.circular(sheetRadius),
              ),
              child: Stack(
                children: [
                  // WebView
                  const Positioned.fill(
                    child: SizedBox.shrink(),
                  ),
                  Positioned.fill(
                    child: WebViewWidget(controller: adController),
                  ),
                  // Touch blocker area - prevents WebView from capturing touches in close button area
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap:
                          () {}, // Absorb taps to prevent WebView from receiving them
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 80,
                        height: 80,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  // Close button overlay
                  Positioned(
                    top: 60,
                    right: 16,
                    child: GestureDetector(
                      onTap: _handleAdIframeClose,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Stack(
        children: [
          // WebView - full screen with safe area
          Positioned.fill(
            child: SafeArea(
              child: WebViewWidget(controller: adController),
            ),
          ),
          // Touch blocker area - prevents WebView from capturing touches in close button area
          Positioned(
            top: touchBlockerTop,
            right: 8,
            child: GestureDetector(
              onTap:
                  () {}, // Absorb taps to prevent WebView from receiving them
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 80,
                height: 80,
                color: Colors.transparent,
              ),
            ),
          ),
          // Close button overlay
          Positioned(
            top: closeButtonTop,
            right: 16,
            child: GestureDetector(
              onTap: _handleAdIframeClose,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.black87,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuModalContent() {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: GestureDetector(
        onTap: _dismissDialog,
        child: Container(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap from closing
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                  minWidth: 320,
                ),
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: widget.theme?.backgroundColor ?? Colors.white,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.9,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          _buildHeader(),
                          // Content
                          Flexible(
                            child: SingleChildScrollView(
                              child: _buildContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Default theme values matching React Native SDK
    final headerColor = widget.theme?.headerColor;
    final borderColor =
        widget.theme?.borderColor ?? const Color.fromRGBO(0, 0, 0, 0.08);
    final titleFontColor =
        widget.theme?.titleFontColor ?? const Color(0xFF1F2937);
    final titleFont = widget.theme?.titleFont;
    final backgroundColor = widget.theme?.backgroundColor ?? Colors.white;
    final secondaryFontColor =
        widget.theme?.secondaryFontColor ?? const Color(0xFF6B7280);
    final accentColor = widget.theme?.accentColor ?? const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          // Character Avatar (tappable from the initial popup)
          Semantics(
            button: true,
            label: 'Change character',
            child: GestureDetector(
              onTap: widget.onCharacterTap,
              child: SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor,
                        border: Border.all(color: accentColor, width: 2),
                      ),
                      child: widget.charImage == null ||
                              widget.charImage!.trim().isEmpty
                          ? Center(
                              child: Text(
                                _getInitials(widget.charName),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: titleFontColor,
                                  fontFamily: titleFont,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            )
                          : ClipOval(
                              child: Image.network(
                                widget.charImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Text(
                                    _getInitials(widget.charName),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: titleFontColor,
                                      fontFamily: titleFont,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: backgroundColor, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Header Text
          Expanded(
            child: Text(
              'Play a Game with ${widget.charName}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleFontColor,
                fontFamily: titleFont,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          // Close Button
          IconButton(
            icon: Icon(Icons.close, color: secondaryFontColor),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Default theme values matching React Native SDK
    final backgroundColor = widget.theme?.backgroundColor ?? Colors.white;
    final secondaryFontColor =
        widget.theme?.secondaryFontColor ?? const Color(0xFF6B7280);
    final secondaryFont = widget.theme?.secondaryFont;
    final titleFontColor =
        widget.theme?.titleFontColor ?? const Color(0xFF1F2937);
    final accentColor = widget.theme?.accentColor ?? const Color(0xFF3B82F6);
    final borderColor =
        widget.theme?.borderColor ?? const Color.fromRGBO(0, 0, 0, 0.08);

    // Check privacy consent
    final notifier = Provider.of<SimulaNotifier>(context, listen: false);
    final hasPrivacyConsent = notifier.hasPrivacyConsent;

    if (!hasPrivacyConsent) {
      final consentMessage = widget.consentRequiredMessage ??
          'Mini games are unavailable. Please enable privacy consent to play sponsored games.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(assets.privacyConsentRequiredImageBase64),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                consentMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryFontColor,
                  fontSize: 14,
                  fontFamily: secondaryFont,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_catalogLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
          height: 400, // Match typical menu height
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: titleFontColor),
                const SizedBox(height: 12),
                Text(
                  'Loading games...',
                  style: TextStyle(
                    color: secondaryFontColor,
                    fontSize: 14,
                    fontFamily: secondaryFont,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_catalogError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.memory(
                    base64Decode(assets.gamesUnavailableImageBase64),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No games are available to play right now. Please check back later!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryFontColor,
                  fontSize: 14,
                  fontFamily: secondaryFont,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Bar
          if (hasPrivacyConsent &&
              !_catalogLoading &&
              !_catalogError &&
              _games.isNotEmpty)
            Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSearchFocused ? accentColor : borderColor,
                  ),
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    return TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _filterGames,
                      decoration: InputDecoration(
                        hintText: 'Search games...',
                        hintStyle: TextStyle(
                          color: secondaryFontColor,
                          fontFamily: secondaryFont,
                        ),
                        prefixIcon:
                            Icon(Icons.search, color: secondaryFontColor),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: secondaryFontColor),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterGames('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: titleFontColor,
                        fontFamily: secondaryFont,
                      ),
                    );
                  },
                ),
              ),
            ),

          // Game Grid
          if (_filteredGames.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No games found for "${_searchController.text}"',
                  style: TextStyle(
                    color: secondaryFontColor,
                    fontSize: 13,
                    fontFamily: secondaryFont,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            )
          else
            GameGrid(
              games: _filteredGames,
              maxGamesToShow: widget.maxGamesToShow,
              charID: widget.charID,
              menuId: _menuId,
              onGameSelect: _handleGameSelect,
              theme: widget.theme,
            ),
        ],
      ),
    );
  }
}
