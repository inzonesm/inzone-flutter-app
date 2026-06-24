import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Reads the score a community game shows on screen, for the third-party
/// "Ultimate Game Stash" HTML games that never report a score through the
/// InZone SDK. Most of them (e.g. Dunk Shot) draw everything — the score
/// included — onto a `<canvas>`, often inside a same-origin container iframe.
///
/// Capture strategy, in order of reliability for canvas games:
///   1. **Canvas pixels** — pull the actual bitmap of every `<canvas>` (main
///      document + same-origin iframes) with `canvas.toDataURL()`. This is the
///      only capture that reliably contains canvas content on Android, where
///      `WebView.takeScreenshot()` returns a blank frame for hardware-
///      accelerated canvas.
///   2. **Native screenshot** — `controller.takeScreenshot()`, a fallback that
///      covers DOM-drawn HUDs and works on iOS.
///   3. **DOM text** — a cheap scrape of visible text / same-origin iframe text
///      for the minority of games that render the score as DOM.
///
/// Each captured image is OCR'd on-device (offline). The score is chosen by
/// first looking for a "best score" / "score" label, then — if no label is
/// recognized — falling back to the most visually prominent integer (largest
/// glyphs), while ignoring the "× 200" coin counter.
class GameScoreReader {
  GameScoreReader({required this.controllerGetter});

  /// Supplies the live webview controller (null until the page is created).
  final InAppWebViewController? Function() controllerGetter;

  static const Duration _throttle = Duration(milliseconds: 1200);
  DateTime? _lastReadAt;
  int? _lastValue;
  Future<int?>? _inFlight;

  /// Best-effort current on-screen score, or null if it can't be determined.
  Future<int?> read() async {
    if (kIsWeb) return _readGameState();

    // Coalesce the warm-on-open read and the share-tap read onto one capture.
    final Future<int?>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final DateTime now = DateTime.now();
    if (_lastReadAt != null && now.difference(_lastReadAt!) < _throttle) {
      return _lastValue;
    }

    final Future<int?> future = _readImpl();
    _inFlight = future;
    try {
      final int? value = await future;
      _lastReadAt = DateTime.now();
      _lastValue = value;
      return value;
    } finally {
      _inFlight = null;
    }
  }

  Future<int?> _readImpl() async {
    final InAppWebViewController? controller = controllerGetter();
    if (controller == null) return null;

    // 1) Read the game's own state first (Construct 2/3 runtime globals & text,
    //    WebStorage, DOM text). This is how the Ultimate Game Stash games —
    //    Construct 2 WebGL exports whose canvas can't be screenshotted — expose
    //    their score. Cheap and exact when it works.
    final int? fromState = await _readGameState();
    if (fromState != null) return fromState;

    // 2) Gather candidate images: canvas bitmaps (the real fix) + a native
    //    screenshot fallback.
    final List<Uint8List> images = <Uint8List>[];
    images.addAll(await _grabCanvasImages(controller));
    final Uint8List? shot = await _takeScreenshot(controller);
    if (shot != null) images.add(shot);

    // 3) OCR each candidate; prefer a label-anchored score, else the most
    //    prominent integer.
    int? anchored;
    int? prominent;
    for (final Uint8List bytes in images.take(4)) {
      final _ScoreGuess guess = await _ocrImage(bytes);
      if (guess.anchored != null) {
        anchored = (anchored == null || guess.anchored! > anchored)
            ? guess.anchored
            : anchored;
      }
      if (guess.prominent != null) {
        prominent = (prominent == null || guess.prominent! > prominent)
            ? guess.prominent
            : prominent;
      }
    }
    return anchored ?? prominent;
  }

  // -------------------------------------------------------------------
  // Capture
  // -------------------------------------------------------------------

  Future<List<Uint8List>> _grabCanvasImages(
      InAppWebViewController controller) async {
    try {
      final dynamic raw =
          await controller.evaluateJavascript(source: _canvasGrabJs);
      if (raw == null) return const <Uint8List>[];
      final List<dynamic> list =
          raw is String ? (jsonDecode(raw) as List<dynamic>) : (raw as List);
      final List<Uint8List> out = <Uint8List>[];
      for (final dynamic item in list) {
        final Uint8List? bytes = _decodeDataUrl(item?.toString());
        if (bytes != null && bytes.isNotEmpty) out.add(bytes);
      }
      return out;
    } catch (_) {
      return const <Uint8List>[];
    }
  }

  Future<Uint8List?> _takeScreenshot(InAppWebViewController controller) async {
    try {
      final Uint8List? bytes = await controller.takeScreenshot();
      return (bytes != null && bytes.isNotEmpty) ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _decodeDataUrl(String? dataUrl) {
    if (dataUrl == null) return null;
    final int comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.startsWith('data:')) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Game-state read (cheap; also the only path on web)
  // -------------------------------------------------------------------

  Future<int?> _readGameState() async {
    final InAppWebViewController? controller = controllerGetter();
    if (controller == null) return null;
    try {
      final dynamic result =
          await controller.evaluateJavascript(source: _gameStateJs);
      return _coerceInt(result);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------
  // OCR
  // -------------------------------------------------------------------

  Future<_ScoreGuess> _ocrImage(Uint8List pngBytes) async {
    File? file;
    TextRecognizer? recognizer;
    try {
      final Directory dir = await getTemporaryDirectory();
      file = File(
        '${dir.path}/inzone_score_${DateTime.now().microsecondsSinceEpoch}_${pngBytes.length}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText result =
          await recognizer.processImage(InputImage.fromFilePath(file.path));
      return _ScoreGuess(
        anchored: _parseScoreFromText(result.text),
        prominent: _mostProminentInt(result),
      );
    } catch (_) {
      return const _ScoreGuess(anchored: null, prominent: null);
    } finally {
      try {
        await recognizer?.close();
      } catch (_) {}
      try {
        await file?.delete();
      } catch (_) {}
    }
  }

  /// A score tied to a "best score" / "score" / "points" label.
  static int? _parseScoreFromText(String text) {
    if (text.isEmpty) return null;
    final String t = text.replaceAll('\n', ' ');
    final RegExpMatch? m = RegExp(
          r'best\s*score\D{0,15}(\d{1,9})',
          caseSensitive: false,
        ).firstMatch(t) ??
        RegExp(
          r'(?:high\s*score|score|points)\D{0,15}(\d{1,9})',
          caseSensitive: false,
        ).firstMatch(t);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  /// The integer drawn with the largest glyphs — for these games that is the
  /// score shown front-and-center. The "× 200" coin counter is skipped (its
  /// element text carries the multiplication sign) so it is never mistaken for
  /// the score.
  static int? _mostProminentInt(RecognizedText recognized) {
    int? best;
    double bestHeight = 0;
    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        final bool coinLine = _looksLikeCoinCounter(line.text);
        for (final TextElement el in line.elements) {
          if (coinLine || _looksLikeCoinCounter(el.text)) continue;
          final int? v = _pureInt(el.text);
          if (v == null) continue;
          final double h = el.boundingBox.height;
          if (h > bestHeight) {
            bestHeight = h;
            best = v;
          }
        }
      }
    }
    return best;
  }

  static bool _looksLikeCoinCounter(String s) =>
      s.contains('×') || s.contains('✕') || RegExp(r'[xX]\s*\d').hasMatch(s);

  static int? _pureInt(String s) {
    final String digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.length > 7) return null;
    // Require the element be mostly digits so labels like "Level3" don't count.
    if (digits.length < s.trim().length - 1) return null;
    return int.tryParse(digits);
  }

  static int? _coerceInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    final String s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return int.tryParse(s);
  }

  // -------------------------------------------------------------------
  // Injected readers (read rendered output only — they do not touch game logic)
  // -------------------------------------------------------------------

  /// Returns a JSON array of `data:image/png;base64,…` URLs, one per canvas in
  /// the main document and every same-origin iframe.
  static const String _canvasGrabJs = r'''
(function () {
  try {
    var urls = [];
    var grab = function (doc) {
      try {
        var cs = doc.getElementsByTagName('canvas');
        for (var i = 0; i < cs.length; i++) {
          try {
            var c = cs[i];
            if (c && c.width > 0 && c.height > 0) {
              urls.push(c.toDataURL('image/png'));
            }
          } catch (e) {}
        }
      } catch (e) {}
    };
    grab(document);
    try {
      var frames = document.getElementsByTagName('iframe');
      for (var f = 0; f < frames.length; f++) {
        try {
          var d = frames[f].contentDocument ||
            (frames[f].contentWindow && frames[f].contentWindow.document);
          if (d) grab(d);
        } catch (e) {}
      }
    } catch (e) {}
    return JSON.stringify(urls);
  } catch (e) {
    return '[]';
  }
})();
''';

  /// Reads the score out of the game's own state. Priority order:
  ///   1. Construct 2 / Construct 3 runtime — `cr_getC2Runtime()` (the engine
  ///      behind the Ultimate Game Stash games): score-named global variables,
  ///      then Text / SpriteFont object contents. C2's minification keeps these
  ///      property names, so this works on the shipped, minified runtime.
  ///   2. WebStorage / localStorage — the persisted "best score".
  ///   3. DOM text (main document + same-origin iframes).
  ///   4. score-named globals on `window`.
  /// Anything labelled "score"/"best"/"high"/"points" is preferred; the
  /// coin/star counter is never matched because it carries no such label.
  /// Returns the score as a string, or null.
  static const String _gameStateJs = r'''
(function () {
  try {
    var best = null;
    var texts = [];
    var consider = function (n, labelled) {
      if (typeof n === 'string') {
        var s = n.trim();
        if (!/^-?\d+(\.\d+)?$/.test(s)) return;
        n = parseFloat(s);
      }
      if (typeof n !== 'number' || !isFinite(n) || n < 0 || n >= 1e7) return;
      if (!labelled) return;
      var iv = Math.round(n);
      if (best === null || iv > best) best = iv;
    };

    // 1) Construct 2 / Construct 3 runtime.
    try {
      var rt = (typeof cr_getC2Runtime === 'function')
        ? cr_getC2Runtime()
        : (window.cr_getC2Runtime ? window.cr_getC2Runtime()
          : (window.c2runtime || window.c3runtime || null));
      if (rt) {
        try {
          var gv = rt.all_global_vars || rt.globalVars || [];
          for (var i = 0; i < gv.length; i++) {
            var g = gv[i];
            if (!g) continue;
            var nm = g.name || g.Name || '';
            var dv = (g.data !== undefined) ? g.data : g.value;
            consider(dv, /score|best|high|point/i.test(nm));
          }
        } catch (e) {}
        try {
          var types = rt.types || {};
          for (var key in types) {
            var t = types[key];
            if (!t || !t.instances) continue;
            for (var j = 0; j < t.instances.length; j++) {
              var inst = t.instances[j];
              if (inst && typeof inst.text === 'string' && inst.text) {
                texts.push(inst.text);
              }
            }
          }
        } catch (e) {}
      }
    } catch (e) {}

    // 2) Persisted best score in WebStorage.
    if (best === null) {
      try {
        for (var li = 0; li < localStorage.length; li++) {
          var lk = localStorage.key(li);
          if (!/score|best|high|point/i.test(lk)) continue;
          consider(localStorage.getItem(lk), true);
        }
      } catch (e) {}
    }

    // 3) DOM text (main document + same-origin iframes).
    try {
      texts.push((document.body && (document.body.innerText || document.body.textContent)) || '');
      var frames = document.getElementsByTagName('iframe');
      for (var fi = 0; fi < frames.length; fi++) {
        try {
          var d = frames[fi].contentDocument ||
            (frames[fi].contentWindow && frames[fi].contentWindow.document);
          if (d && d.body) texts.push(d.body.innerText || d.body.textContent || '');
        } catch (e) {}
      }
    } catch (e) {}

    // 4) score-named globals on window.
    if (best === null) {
      try {
        var keys = Object.getOwnPropertyNames(window);
        for (var ki = 0; ki < keys.length; ki++) {
          var k = keys[ki];
          if (!/score|best|high|point/i.test(k)) continue;
          var v;
          try { v = window[k]; } catch (e) { continue; }
          if (typeof v === 'number') consider(v, true);
        }
      } catch (e) {}
    }

    // 5) Anchored text from everything collected above.
    if (best === null) {
      var joined = texts.join(' \n ');
      var m = joined.match(/best\s*score[^0-9]{0,15}(\d{1,7})/i)
           || joined.match(/(?:high\s*score|score|points)[^0-9]{0,15}(\d{1,7})/i);
      if (m) best = parseInt(m[1], 10);
    }

    return (best === null) ? null : String(best);
  } catch (e) {
    return null;
  }
})();
''';
}

class _ScoreGuess {
  const _ScoreGuess({required this.anchored, required this.prominent});

  /// A number found next to a "score" label.
  final int? anchored;

  /// The largest-glyph integer on screen (label-independent).
  final int? prominent;
}
