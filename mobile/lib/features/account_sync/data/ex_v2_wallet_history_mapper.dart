import 'package:trading_mobile/features/account_sync/data/ex_v2_demo_mapper.dart';
import 'package:trading_mobile/features/account_sync/domain/ex_v2_models.dart';
import 'package:trading_mobile/shared/models/demo_models.dart';

abstract final class ExV2WalletHistoryMapper {
  static const _depositReferencePrefix = 'D-ALLINT-USD-INT-';
  static const _withdrawalReferencePrefix = 'W-BANKVNGT-USD-';
  static const _depositReferenceDigits = 12;
  static const _withdrawalReferenceDigits = 13;
  static final _referenceEpoch = DateTime.utc(2000);
  static final _canonicalUuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isSettled(JsonMap json) => _isSettled(json);

  static double settledDepositTotal({
    required Iterable<JsonMap> historyTransactions,
    required Iterable<JsonMap> deposits,
  }) =>
      entries(
            historyTransactions: historyTransactions
                .where(_isSettled)
                .toList(growable: false),
            deposits: deposits.where(_isSettled).toList(growable: false),
            withdrawals: const [],
          )
          .where((entry) => entry.profit > 0)
          .fold<double>(0, (total, entry) => total + entry.profit);

  static List<DemoHistoryPosition> entries({
    required List<JsonMap> historyTransactions,
    required List<JsonMap> deposits,
    required List<JsonMap> withdrawals,
  }) {
    final transactions = historyTransactions
        .map((json) => _candidate(json))
        .whereType<_WalletHistoryCandidate>()
        .toList(growable: false);
    final requests = <_WalletHistoryCandidate>[
      ...deposits
          .map((json) => _candidate(json, sourceType: 'deposit'))
          .whereType<_WalletHistoryCandidate>(),
      ...withdrawals
          .map((json) => _candidate(json, sourceType: 'withdrawal'))
          .whereType<_WalletHistoryCandidate>(),
    ];
    final matchedRequests = <int>{};
    final rows = <_WalletHistoryRow>[];
    final seenKeys = <String>{};

    void add(
      _WalletHistoryCandidate canonical, {
      _WalletHistoryCandidate? metadata,
    }) {
      final canonicalWithdrawalSuffix = canonical.type == 'withdrawal'
          ? _canonicalWithdrawalReferenceSuffix(canonical, metadata: metadata)
          : null;
      final reference = _displayReference(
        canonical,
        metadata: metadata,
        canonicalWithdrawalSuffix: canonicalWithdrawalSuffix,
      );
      final referenceIsAuthoritative =
          (canonical.type == 'deposit' &&
              _referenceSuffix(
                    canonical.depositTransactionCode,
                    _depositReferenceDigits,
                  ) !=
                  null) ||
          canonicalWithdrawalSuffix != null;
      final duplicateKeys = <String>{
        'reference:${reference.toLowerCase()}',
        for (final identifier in canonical.identifiers)
          'id:${identifier.toLowerCase()}',
      };
      if (duplicateKeys.any(seenKeys.contains)) return;
      seenKeys.addAll(duplicateKeys);

      final id = canonical.identifiers.firstOrNull ?? reference;
      rows.add(
        _WalletHistoryRow(
          occurredAt: canonical.occurredAt,
          entry: DemoHistoryPosition(
            id: 'wallet-$id',
            title: 'Balance',
            profit: canonical.type == 'withdrawal'
                ? -canonical.amount.abs()
                : canonical.amount.abs(),
            time: ExV2DemoMapper.dateLabel(canonical.occurredAt),
            subtitle: reference,
            referenceIsAuthoritative: referenceIsAuthoritative,
          ),
        ),
      );
    }

    for (final transaction in transactions) {
      final matchIndex = _matchingRequestIndex(
        transaction,
        requests,
        matchedRequests,
      );
      final request = matchIndex == null ? null : requests[matchIndex];
      if (matchIndex != null) matchedRequests.add(matchIndex);
      add(transaction, metadata: request);
    }
    for (var index = 0; index < requests.length; index++) {
      if (!matchedRequests.contains(index)) add(requests[index]);
    }

    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return normalizeReferences(rows.map((row) => row.entry));
  }

  static _WalletHistoryCandidate? _candidate(
    JsonMap json, {
    String? sourceType,
  }) {
    final type = sourceType ?? _transactionType(json);
    if (type == null) return null;
    final amount = _number(json, const [
      'amount',
      'amountValue',
      'netAmount',
      'creditedAmount',
      'value',
    ]);
    final occurredAt = _date(json, const [
      'completedAt',
      'completedAtUtc',
      'processedAt',
      'processedAtUtc',
      'approvedAt',
      'approvedAtUtc',
      'timestamp',
      'updatedAt',
      'updatedAtUtc',
      'createdAt',
      'createdAtUtc',
      'time',
    ]);
    if (amount == null || occurredAt == null) return null;
    return _WalletHistoryCandidate(
      json: json,
      type: type,
      amount: amount,
      currency: _text(json, const ['currency']),
      occurredAt: occurredAt,
      matchAt:
          _date(json, const ['createdAt', 'createdAtUtc', 'timestamp']) ??
          occurredAt,
      identifiers: _identifiers(json),
      depositTransactionCode: sourceType == null && type == 'deposit'
          ? _text(json, const [
              'invoice',
              'transactionCode',
              'transactionNumber',
            ])
          : null,
      explicitReference: _text(json, const [
        'reference',
        'transactionReference',
        'externalReference',
      ]),
    );
  }

  static int? _matchingRequestIndex(
    _WalletHistoryCandidate transaction,
    List<_WalletHistoryCandidate> requests,
    Set<int> matchedRequests,
  ) {
    final reference = transaction.explicitReference?.toLowerCase();
    if (reference != null) {
      for (var index = 0; index < requests.length; index++) {
        if (matchedRequests.contains(index)) continue;
        if (requests[index].explicitReference?.toLowerCase() == reference) {
          return index;
        }
      }
    }
    for (var index = 0; index < requests.length; index++) {
      if (matchedRequests.contains(index)) continue;
      final request = requests[index];
      if (request.type != transaction.type ||
          (request.amount - transaction.amount).abs() > 0.000001 ||
          !_sameCurrency(request.currency, transaction.currency)) {
        continue;
      }
      if (request.matchAt.difference(transaction.matchAt).abs() <=
          const Duration(seconds: 2)) {
        return index;
      }
    }
    return null;
  }

  static bool _sameCurrency(String? left, String? right) =>
      left == null ||
      right == null ||
      left.toUpperCase() == right.toUpperCase();

  static String _displayReference(
    _WalletHistoryCandidate canonical, {
    _WalletHistoryCandidate? metadata,
    int? canonicalWithdrawalSuffix,
  }) {
    final detail = metadata ?? canonical;
    final explicit = detail.explicitReference ?? canonical.explicitReference;
    final isWithdrawal = canonical.type == 'withdrawal';
    final prefix = isWithdrawal
        ? _withdrawalReferencePrefix
        : _depositReferencePrefix;
    final depositTransactionSuffix = _referenceSuffix(
      canonical.depositTransactionCode,
      _depositReferenceDigits,
    );
    if (!isWithdrawal && depositTransactionSuffix != null) {
      return '$prefix${depositTransactionSuffix.toString().padLeft(_depositReferenceDigits, '0')}';
    }
    final digits = isWithdrawal
        ? _withdrawalReferenceDigits
        : _depositReferenceDigits;
    final suffix =
        _referenceSuffix(explicit, digits) ??
        canonicalWithdrawalSuffix ??
        _generatedReferenceSuffix(canonical, digits);
    return '$prefix${suffix.toString().padLeft(digits, '0')}';
  }

  static int? _canonicalWithdrawalReferenceSuffix(
    _WalletHistoryCandidate canonical, {
    _WalletHistoryCandidate? metadata,
  }) {
    for (final source in [metadata, canonical]) {
      if (source == null) continue;
      for (final identifier in source.identifiers) {
        if (!_canonicalUuidPattern.hasMatch(identifier)) continue;
        final value = BigInt.tryParse(
          identifier.replaceAll('-', ''),
          radix: 16,
        );
        if (value == null) continue;
        final minimum = BigInt.from(1000000000000);
        final range = BigInt.from(9000000000000);
        return (minimum + value % range).toInt();
      }
    }
    return null;
  }

  static List<DemoHistoryPosition> normalizeReferences(
    Iterable<DemoHistoryPosition> entries,
  ) {
    final lastSuffixByType = <String, int>{};
    return entries
        .map((entry) {
          if (!entry.isBalance || entry.title.toLowerCase() != 'balance') {
            return entry;
          }
          final isWithdrawal =
              (entry.subtitle?.toUpperCase().startsWith('W-') ?? false) ||
              entry.profit < 0;
          final type = isWithdrawal ? 'withdrawal' : 'deposit';
          final prefix = isWithdrawal
              ? _withdrawalReferencePrefix
              : _depositReferencePrefix;
          final digits = isWithdrawal
              ? _withdrawalReferenceDigits
              : _depositReferenceDigits;
          final authoritativeSuffix = entry.referenceIsAuthoritative
              ? _referenceSuffix(entry.subtitle, digits)
              : null;
          if (authoritativeSuffix != null) {
            final previous = lastSuffixByType[type];
            if (previous == null || authoritativeSuffix > previous) {
              lastSuffixByType[type] = authoritativeSuffix;
            }
            return entry;
          }
          final candidate =
              _referenceSuffix(entry.subtitle, digits) ??
              _generatedEntryReferenceSuffix(entry, digits);
          final previous = lastSuffixByType[type];
          final suffix = previous != null && candidate <= previous
              ? previous + 1
              : candidate;
          lastSuffixByType[type] = suffix;
          final normalizedReference =
              '$prefix${suffix.toString().padLeft(digits, '0')}';
          if (normalizedReference == entry.subtitle) return entry;
          return DemoHistoryPosition(
            id: entry.id,
            title: entry.title,
            profit: entry.profit,
            time: entry.time,
            side: entry.side,
            volume: entry.volume,
            openPrice: entry.openPrice,
            closePrice: entry.closePrice,
            subtitle: normalizedReference,
            referenceIsAuthoritative: entry.referenceIsAuthoritative,
          );
        })
        .toList(growable: false);
  }

  static int? _referenceSuffix(String? value, int digits) {
    if (value == null) return null;
    final match = RegExp(r'(\d+)$').firstMatch(value.trim());
    final raw = match?.group(1);
    if (raw == null || raw.length != digits) return null;
    return int.tryParse(raw);
  }

  static int _generatedReferenceSuffix(
    _WalletHistoryCandidate candidate,
    int digits,
  ) => _generatedReferenceSuffixAt(candidate.occurredAt, digits);

  static int _generatedEntryReferenceSuffix(
    DemoHistoryPosition entry,
    int digits,
  ) {
    final components = RegExp(
      r'^(\d{4})\.(\d{2})\.(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(entry.time);
    final occurredAt = components == null
        ? _referenceEpoch
        : DateTime(
            int.parse(components.group(1)!),
            int.parse(components.group(2)!),
            int.parse(components.group(3)!),
            int.parse(components.group(4)!),
            int.parse(components.group(5)!),
            int.parse(components.group(6)!),
          );
    return _generatedReferenceSuffixAt(occurredAt, digits);
  }

  static int _generatedReferenceSuffixAt(DateTime occurredAt, int digits) {
    final elapsedMilliseconds =
        occurredAt.toUtc().millisecondsSinceEpoch -
        _referenceEpoch.millisecondsSinceEpoch;
    final chronologicalOffset = elapsedMilliseconds < 0
        ? 0
        : digits == _depositReferenceDigits
        ? elapsedMilliseconds ~/ 10
        : elapsedMilliseconds;
    final minimum = digits == _depositReferenceDigits
        ? 100000000000
        : 1000000000000;
    final maximum = digits == _depositReferenceDigits
        ? 999999999999
        : 9999999999999;
    final generated = minimum + chronologicalOffset;
    return generated > maximum ? maximum : generated;
  }

  static String? _transactionType(JsonMap json) {
    final value = _text(json, const [
      'type',
      'transactionType',
      'kind',
      'requestType',
    ])?.toLowerCase();
    if (value == null) return null;
    if (value.contains('withdraw') ||
        value.contains('rút') ||
        value.contains('rut')) {
      return 'withdrawal';
    }
    if (value.contains('deposit') ||
        value.contains('nạp') ||
        value.contains('nap')) {
      return 'deposit';
    }
    return null;
  }

  static bool _isSettled(JsonMap json) {
    final status = _text(json, const ['status', 'state'])?.toLowerCase();
    if (status == null) return false;
    return const {
      'approved',
      'complete',
      'completed',
      'credited',
      'paid',
      'processed',
      'succeeded',
      'success',
      'hoàn tất',
      'hoan tat',
      'đã duyệt',
      'da duyet',
    }.contains(status);
  }

  static List<String> _identifiers(JsonMap json) {
    final values = <String>[];
    for (final key in const [
      'id',
      'transactionId',
      'requestId',
      'depositId',
      'withdrawalId',
    ]) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !values.contains(value)) {
        values.add(value);
      }
    }
    return values;
  }

  static String? _text(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? _number(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _date(JsonMap json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is! String) continue;
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }
}

final class _WalletHistoryCandidate {
  const _WalletHistoryCandidate({
    required this.json,
    required this.type,
    required this.amount,
    required this.currency,
    required this.occurredAt,
    required this.matchAt,
    required this.identifiers,
    required this.depositTransactionCode,
    required this.explicitReference,
  });

  final JsonMap json;
  final String type;
  final double amount;
  final String? currency;
  final DateTime occurredAt;
  final DateTime matchAt;
  final List<String> identifiers;
  final String? depositTransactionCode;
  final String? explicitReference;
}

final class _WalletHistoryRow {
  const _WalletHistoryRow({required this.occurredAt, required this.entry});

  final DateTime occurredAt;
  final DemoHistoryPosition entry;
}
