import 'package:fractional_indexing_dart/fractional_indexing_dart.dart';

/// Thin wrapper around fractional_indexing_dart providing convenience methods
/// for the outliner's ordering needs.
class FractionalIndexHelper {
  /// Generate the initial index for the first node.
  /// Returns 'a0'.
  static String generateInitialIndex() {
    return FractionalIndexing.generateKeyBetween(null, null);
  }

  /// Generate an index between two existing indices.
  /// Both [prev] and [next] can be null:
  /// - prev=null, next=null → first key ('a0')
  /// - prev=key, next=null → key after last
  /// - prev=null, next=key → key before first
  /// - prev=key, next=key → midpoint key
  static String generateBetween(String? prev, String? next) {
    return FractionalIndexing.generateKeyBetween(prev, next);
  }

  /// Generate an index after the last sibling.
  static String generateAfter(String last) {
    return FractionalIndexing.generateKeyBetween(last, null);
  }

  /// Generate an index before the first sibling.
  static String generateBefore(String first) {
    return FractionalIndexing.generateKeyBetween(null, first);
  }

  /// Generate [count] evenly-spaced keys between [prev] and [next].
  static List<String> generateNBetween(String? prev, String? next, int count) {
    return FractionalIndexing.generateNKeysBetween(prev, next, count);
  }
}
