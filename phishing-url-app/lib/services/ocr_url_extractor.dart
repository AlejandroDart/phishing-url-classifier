class OcrUrlExtractor {
  static final RegExp _explicitUrl = RegExp(
    r'''(?:https?|hxxps?)://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+''',
    caseSensitive: false,
  );

  static final RegExp _wwwUrl = RegExp(
    r'''www\.[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+''',
    caseSensitive: false,
  );

  static final RegExp _bareDomain = RegExp(
    r'''(?:^|[\s(<\[{'"])((?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(?::\d{1,5})?(?:/[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]*)?)''',
    caseSensitive: false,
  );

  static String? extract(String rawText) {
    if (rawText.trim().isEmpty) return null;

    final normalized = _normalizeCharacters(rawText);
    final lines = normalized
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final variants = <String>{normalized};

    for (final line in lines) {
      variants.add(line);
    }
    for (var index = 0; index < lines.length - 1; index++) {
      variants.add('${lines[index]}${lines[index + 1]}');
      variants.add('${lines[index]} ${lines[index + 1]}');
    }

    final candidates = <_UrlCandidate>[];
    var order = 0;
    for (final variant in variants) {
      final compact = _compactUrlPunctuation(variant);
      for (final match in _explicitUrl.allMatches(compact)) {
        candidates.add(_UrlCandidate(match.group(0)!, 3, order++));
      }
      for (final match in _wwwUrl.allMatches(compact)) {
        candidates.add(_UrlCandidate(match.group(0)!, 2, order++));
      }
      for (final match in _bareDomain.allMatches(compact)) {
        candidates.add(_UrlCandidate(match.group(1)!, 1, order++));
      }
    }

    candidates.sort((first, second) {
      final priority = second.priority.compareTo(first.priority);
      return priority != 0 ? priority : first.order.compareTo(second.order);
    });

    final seen = <String>{};
    for (final candidate in candidates) {
      final normalizedUrl = normalize(candidate.value);
      if (normalizedUrl == null || !seen.add(normalizedUrl)) continue;
      return normalizedUrl;
    }
    return null;
  }

  static String? normalize(String value) {
    var url = _normalizeCharacters(value).trim();
    url = _compactUrlPunctuation(url);
    url = url.replaceFirst(
        RegExp(r'^hxxps://', caseSensitive: false), 'https://');
    url =
        url.replaceFirst(RegExp(r'^hxxp://', caseSensitive: false), 'http://');
    url = url.replaceFirstMapped(RegExp(r'^https?//', caseSensitive: false),
        (match) {
      final scheme =
          match.group(0)!.toLowerCase().startsWith('https') ? 'https' : 'http';
      return '$scheme://';
    });
    url = url.replaceFirstMapped(
        RegExp(r'^https?:/([^/])', caseSensitive: false),
        (match) =>
            '${url.toLowerCase().startsWith('https') ? 'https' : 'http'}://${match.group(1)}');
    url = url.replaceAll(RegExp(r'''[.,;:!?)\]}>'"]+$'''), '');

    if (url.toLowerCase().startsWith('www.')) {
      url = 'https://$url';
    } else if (!RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
        .hasMatch(url)) {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      return null;
    }
    if (!_isValidHost(uri.host) || uri.userInfo.isNotEmpty) return null;
    if (uri.port < 1 || uri.port > 65535) return null;
    return uri.toString();
  }

  static String _normalizeCharacters(String value) {
    return value
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[。．｡]'), '.')
        .replaceAll('／', '/')
        .replaceAll('：', ':');
  }

  static String _compactUrlPunctuation(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'\b(https?|hxxps?)\s*:\s*', caseSensitive: false),
          (match) => '${match.group(1)}:',
        )
        .replaceAllMapped(
          RegExp(r'([A-Za-z0-9.])\s*:\s*(\d{1,5})(?=[/\s]|$)'),
          (match) => '${match.group(1)}:${match.group(2)}',
        )
        .replaceAll(RegExp(r'\s*/\s*'), '/')
        .replaceAll(RegExp(r'\s*\.\s*'), '.')
        .replaceAll(RegExp(r'\s*\?\s*'), '?')
        .replaceAll(RegExp(r'\s*&\s*'), '&')
        .replaceAll(RegExp(r'\s*=\s*'), '=')
        .replaceAll(RegExp(r'\s*#\s*'), '#')
        .replaceAllMapped(
          RegExp(r'\b(https?|hxxps?)//', caseSensitive: false),
          (match) => '${match.group(1)}://',
        );
  }

  static bool _isValidHost(String host) {
    if (host.isEmpty || host.length > 253 || !host.contains('.')) return false;
    final ipv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
    if (ipv4.hasMatch(host)) {
      return host.split('.').every((part) {
        final value = int.tryParse(part);
        return value != null && value >= 0 && value <= 255;
      });
    }

    final labels = host.split('.');
    if (labels.length < 2 || labels.last.length < 2) return false;
    return labels.every(
      (label) =>
          label.isNotEmpty &&
          label.length <= 63 &&
          RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$').hasMatch(label),
    );
  }
}

class _UrlCandidate {
  const _UrlCandidate(this.value, this.priority, this.order);

  final String value;
  final int priority;
  final int order;
}
