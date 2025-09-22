import 'dart:math';

/// An advanced search engine for transactions featuring an inverted index
/// for performance and fuzzy matching for better search results.
class TransactionSearchEngine {
  /// The inverted index. Maps a term to a set of transaction IDs.
  final Map<String, Set<int>> _invertedIndex = {};

  /// A map from transaction ID to the full transaction object for quick retrieval.
  final Map<int, Map<String, dynamic>> _transactions = {};

  /// A set of all unique terms (the vocabulary) for fuzzy matching.
  final Set<String> _vocabulary = {};

  /// Creates a search engine and builds the index from the provided transactions.
  TransactionSearchEngine(List<Map<String, dynamic>> transactions) {
    _buildIndex(transactions);
  }

  /// Builds the inverted index from the list of transactions.
  void _buildIndex(List<Map<String, dynamic>> transactions) {
    for (final tx in transactions) {
      final txId = tx['id'] as int;
      _transactions[txId] = tx;

      // Extract and combine text from various fields for indexing.
      final description = (tx['description'] as String? ?? '').toLowerCase();
      final dateStr = (tx['date'] as String? ?? '').toLowerCase();
      final lines =
          (tx['lines'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final accountText = lines
          .map((l) =>
              (l['account'] as String? ?? '').toLowerCase().replaceAll(':', ' '))
          .join(' ');
      final amountText = lines.map((l) {
        final debit = (l['debit'] as num?)?.toDouble() ?? 0.0;
        final credit = (l['credit'] as num?)?.toDouble() ?? 0.0;
        return '$debit $credit';
      }).join(' ');

      final fullText = '$description $dateStr $accountText $amountText';

      // Tokenize the text and update the index and vocabulary.
      final terms = _tokenize(fullText);
      for (final term in terms) {
        if (term.isNotEmpty) {
          _vocabulary.add(term);
          _invertedIndex.putIfAbsent(term, () => {}).add(txId);
        }
      }
    }
  }

  /// A simple tokenizer that splits text by non-alphanumeric characters.
  Set<String> _tokenize(String text) {
    return text.split(RegExp(r'[^a-z0-9\.]+')).where((s) => s.length > 1).toSet();
  }

  /// Calculates the Levenshtein distance between two strings for fuzzy matching.
  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List.generate(b.length + 1, (i) => i);
    List<int> v1 = List.generate(b.length + 1, (i) => 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      v0 = v1.toList();
    }
    return v1[b.length];
  }

  /// Searches transactions based on a query and optional filters.
  /// The query is tokenized, and each token is matched exactly or fuzzily
  /// against the indexed vocabulary.
  List<Map<String, dynamic>> search(String query,
      {Map<String, dynamic>? filters}) {
    final searchTerms = _tokenize(query.toLowerCase());

    if (searchTerms.isEmpty && (filters == null || filters.isEmpty)) {
      return _transactions.values.toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    }

    Set<int> matchingTxIds;

    if (searchTerms.isNotEmpty) {
      Set<int> termResults = {};
      for (final term in searchTerms) {
        final Set<int> currentTermIds = {};
        // Find exact and fuzzy matches in the vocabulary.
        for (final vocabTerm in _vocabulary) {
          if (_levenshtein(term, vocabTerm) <= 1) { // Fuzzy threshold
            currentTermIds.addAll(_invertedIndex[vocabTerm] ?? {});
          }
        }
        // Intersect results for multi-word queries (AND logic).
        termResults = termResults.isEmpty
            ? currentTermIds
            : termResults.intersection(currentTermIds);
      }
      matchingTxIds = termResults;
    } else {
      matchingTxIds = _transactions.keys.toSet();
    }

    // Apply additional filters to the search results.
    List<Map<String, dynamic>> results =
        matchingTxIds.map((id) => _transactions[id]!).where((tx) {
      if (filters != null && filters.containsKey('type')) {
        final type = (filters['type'] as String?) ?? 'all';
        if (type != 'all') {
          final lines = (tx['lines'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          return lines.any((l) =>
              (type == 'debit' && ((l['debit'] as num?) ?? 0) > 0) ||
              (type == 'credit' && ((l['credit'] as num?) ?? 0) > 0));
        }
      }
      return true;
    }).toList();

    results.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return results;
  }
}