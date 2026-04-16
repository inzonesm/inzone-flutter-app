import 'package:flutter/material.dart';
import 'package:inzone/services/translation/free_translation_service.dart';
import 'package:inzone/services/translation/premium_translation_router.dart';
import 'package:inzone/services/translation/translation_result.dart';
import 'package:inzone/services/translation/translation_settings_controller.dart';
import 'package:provider/provider.dart';

class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool showImproveButton;

  const TranslatableText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.showImproveButton = true,
  });

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  Future<TranslationResult>? _translationFuture;
  String? _lastText;
  String? _lastTargetLanguageCode;
  bool? _lastTranslationEnabled;

  @override
  void initState() {
    super.initState();
    _prepareTranslationIfNeeded(context.read<TranslationSettingsController>());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareTranslationIfNeeded(context.read<TranslationSettingsController>());
  }

  @override
  void didUpdateWidget(covariant TranslatableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareTranslationIfNeeded(context.read<TranslationSettingsController>());
  }

  void _prepareTranslationIfNeeded(TranslationSettingsController settings) {
    final shouldRefresh = _lastText != widget.text ||
        _lastTargetLanguageCode != settings.targetLanguageCode ||
        _lastTranslationEnabled != settings.translationEnabled;

    if (!shouldRefresh) {
      return;
    }

    _lastText = widget.text;
    _lastTargetLanguageCode = settings.targetLanguageCode;
    _lastTranslationEnabled = settings.translationEnabled;

    if (!settings.translationEnabled || widget.text.trim().isEmpty) {
      _translationFuture = null;
      return;
    }

    _translationFuture = FreeTranslationService.instance.translate(
      originalText: widget.text,
      targetLanguageCode: settings.targetLanguageCode,
    );
  }

  Future<void> _requestPremium(TranslationResult result) async {
    final premiumResult =
        await PremiumTranslationRouter.instance.requestNuancedTranslation(
      originalText: widget.text,
      sourceLanguageCode: result.sourceLanguageCode,
      targetLanguageCode: result.targetLanguageCode,
    );

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final message = premiumResult.usedPremiumRoute
        ? 'Premium translation route request logged. Configure a premium provider next.'
        : 'Premium translation completed.';

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TranslationSettingsController>();
    _prepareTranslationIfNeeded(settings);

    if (!settings.translationEnabled || widget.text.trim().isEmpty) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        overflow: widget.overflow,
        maxLines: widget.maxLines,
      );
    }

    return FutureBuilder<TranslationResult>(
      future: _translationFuture,
      builder: (context, snapshot) {
        final result = snapshot.data;

        final displayText = (result != null && result.wasTranslated)
            ? result.translatedText
            : widget.text;

        final canImprove = widget.showImproveButton &&
            settings.showImproveAction &&
            result != null;

        if (!canImprove) {
          return Text(
            displayText,
            style: widget.style,
            textAlign: widget.textAlign,
            overflow: widget.overflow,
            maxLines: widget.maxLines,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayText,
              style: widget.style,
              textAlign: widget.textAlign,
              overflow: widget.overflow,
              maxLines: widget.maxLines,
            ),
            const SizedBox(height: 2),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              ),
              onPressed: () => _requestPremium(result),
              child: const Text(
                'Improve translation',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }
}
