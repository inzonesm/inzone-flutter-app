import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inzone/theme/app_colors.dart';
import 'package:toasty_box/toast_service.dart';

import '../social_actions_service.dart';

/// Dialog for "Share score to InZone": a small post composer that creates a
/// home-feed post via `InZoneDatabase.createRepost` — the same call the
/// simula Game Over popup's "Share Progress" flow makes.
///
/// Styled to match the existing Game Over dialog: 24-radius dialog, blue
/// gradient header with the **specific game's icon** in a translucent
/// circle, and the gradient action button.
Future<void> showPostComposerPopup(
  BuildContext context, {
  required SocialActionsService actions,
  required int? score,
}) {
  return showDialog(
    context: context,
    builder: (_) => _PostComposerDialog(actions: actions, score: score),
  );
}

class _PostComposerDialog extends StatefulWidget {
  const _PostComposerDialog({required this.actions, required this.score});

  final SocialActionsService actions;
  final int? score;

  @override
  State<_PostComposerDialog> createState() => _PostComposerDialogState();
}

class _PostComposerDialogState extends State<_PostComposerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.actions.prewrittenMessage(widget.score),
  );
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_posting || _controller.text.trim().isEmpty) return;
    setState(() => _posting = true);

    // Capture context-derived values before the dialog is popped, so the
    // toast can outlive this State's own context.
    final navigator = Navigator.of(context);
    final toastContext = navigator.context;
    final cardColor = Theme.of(context).cardColor;

    try {
      final result = await widget.actions.createScorePost(
        _controller.text,
        widget.score,
      );
      if (!mounted) return;
      final blocked = result['blocked'] == true;
      final success = result['success'] == true;
      navigator.pop();
      ToastService.showToast(
        toastContext,
        backgroundColor: cardColor,
        shadowColor: Colors.transparent,
        leading: Icon(
          blocked || !success ? Icons.error_outline : Icons.celebration,
          color:
              blocked || !success ? AppColors.error : AppColors.primaryBlue,
        ),
        message: blocked
            ? "This post couldn't be shared."
            : success
                ? 'Shared to your InZone feed!'
                : "Couldn't post — try again.",
      );
    } catch (_) {
      if (mounted) {
        setState(() => _posting = false);
        ToastService.showToast(
          toastContext,
          backgroundColor: cardColor,
          shadowColor: Colors.transparent,
          leading: const Icon(Icons.error_outline, color: AppColors.error),
          message: "Couldn't post — try again.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = widget.actions.game;
    final iconUrl = game.iconUrl.trim();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header — mirrors the Game Over dialog header, with
            // the specific game's icon in the circle.
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: iconUrl.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Text('🎮',
                                    style: TextStyle(fontSize: 26)),
                              ),
                            ),
                          )
                        : const Center(
                            child:
                                Text('🎮', style: TextStyle(fontSize: 26)),
                          ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Share to InZone',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            // Composer body.
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.score != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '🏆 Score: ${widget.score}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 280,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: 'Say something…'),
                  ),
                  const SizedBox(height: 8),
                  // Gradient post button — same proportions as the Game Over
                  // dialog's "Challenge a Friend" button.
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _posting ? null : _post,
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_posting)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(Icons.campaign_rounded,
                                    color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              const Text(
                                'Post to InZone',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: theme.textTheme.bodySmall?.color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
