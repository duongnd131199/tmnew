class ReferenceTypographySource {
  const ReferenceTypographySource({
    required this.id,
    required this.path,
    required this.sha256,
    required this.width,
    required this.height,
    required this.encoding,
    required this.authority,
    required this.theme,
    required this.losslessSource,
    required this.hasCaptureProvenance,
    required this.certificationEligible,
  });

  final String id;
  final String path;
  final String sha256;
  final int width;
  final int height;
  final String encoding;
  final String authority;
  final String theme;
  final bool losslessSource;
  final bool hasCaptureProvenance;
  final bool certificationEligible;
}

enum ReferenceStructuralDelimiterOwner { deterministicVectorShape }

class ReferenceStructuralDelimiterPolicy {
  const ReferenceStructuralDelimiterPolicy({
    required this.key,
    required this.specimen,
    required this.delimiterText,
    required this.codePoints,
    required this.candidateRunKey,
    required this.owner,
    required this.renderingContract,
  });

  final String key;
  final String specimen;
  final String delimiterText;
  final Set<int> codePoints;
  final String candidateRunKey;
  final ReferenceStructuralDelimiterOwner owner;
  final String renderingContract;
}

const referenceTypographySources = <ReferenceTypographySource>[
  ReferenceTypographySource(
    id: 'prices',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-10.jpg',
    sha256: '6739a1668fa87ca745f5e43ea472c2413ef0434fa1074c3b180c7278ea658db5',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-prices',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'chart',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-17.jpg',
    sha256: 'e5d878286e76f843fec97ac2fc14de68d219fd20475a381a2bda941226854e31',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-chart',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'trade-light',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-20.jpg',
    sha256: '5c619acae61c2cbf11f6210a0888fe0cd2cf5fb49917e9189015c9431769becc',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-trade',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'history-positions',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-23.jpg',
    sha256: '40bfd8ddf3e24158453da32e4318e9219d02a201b09bb2fb53d6ee95a98a5924',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-history-positions',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'history-orders-offset',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-26.jpg',
    sha256: '48dbab6778e247325222bf0e10e991f0ef4d160ecf4cb4127be1e6d1b6eb83c1',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-history-orders-offset',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'history-orders-summary',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-29.jpg',
    sha256: '7f8d2fe5c086eacb5a8364435373645a4ba3e2ba3df7b852467b5a51d0ee45ee',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-history-orders-summary',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'history-deals-summary',
    path: '../iconMau/anhmau/photo_2026-08-25_22-30-34.jpg',
    sha256: '6fbbf3ccfc834b94052df32713a153c10518298b644844fb9482fa51a70e3bb9',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'canonical-history-deals-summary',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'settings-primary',
    path: '../iconMau/anhmau/image.png',
    sha256: '4c4f508369707ef576521c220e918bc0db5c9f3bdb900334ff5a5a859fcfcf9c',
    width: 590,
    height: 1280,
    encoding: 'png',
    authority: 'primary-settings',
    theme: 'light',
    losslessSource: true,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'settings-secondary',
    path: '../iconMau/anhmau/photo_2026-08-27_21-13-34.jpg',
    sha256: 'bf67307f7e12f378ac2bf6abbbdf3b351d1e5492d59a50f0a0233b9a8955d092',
    width: 590,
    height: 1280,
    encoding: 'jpeg',
    authority: 'secondary-settings-shared-roles',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'trade-dark',
    path: '../iconMau/anhmau/photo_2026-08-21_16-51-41.jpg',
    sha256: '349b41ed7ab4e974966b7bf1394e65f39cd43f07667613c5f92f0e2e8b2cefe9',
    width: 413,
    height: 881,
    encoding: 'jpeg',
    authority: 'separate-dark-trade',
    theme: 'dark',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
  ReferenceTypographySource(
    id: 'partial-system-ui-crop',
    path: '../iconMau/anhmau/photo_2026-08-31_10-47-10.jpg',
    sha256: '3e6d3c3693119c96f78c56e07638f54a16e8238911ec55b7cc94bddfb65ced57',
    width: 336,
    height: 331,
    encoding: 'jpeg',
    authority: 'partial-system-ui-crop',
    theme: 'light',
    losslessSource: false,
    hasCaptureProvenance: false,
    certificationEligible: false,
  ),
];

/// Task 1's immutable glyph-coverage corpus. Later role manifests may append
/// strings, but the baseline font lock must always cover these eleven samples.
const referenceTypographySpecimenStrings = <String>[
  'Giá  Biểu đồ  Giao dịch  Lịch sử  Cài đặt',
  'Số dư:',
  'Vốn:',
  'Tiền ký quỹ:',
  'Mức ký quỹ (%):',
  'XAUUSD buy 1',
  '4637.05 → 4640.81',
  '376.00  -341.00',
  '103 310.00  203.24',
  'L:  H:  M1',
  'Orders  Deals',
];

const referenceTypographyStructuralDelimiterPolicies =
    <ReferenceStructuralDelimiterPolicy>[
      ReferenceStructuralDelimiterPolicy(
        key: 'numeric-price-arrow',
        specimen: '4637.05 → 4640.81',
        delimiterText: '→',
        codePoints: <int>{0x2192},
        candidateRunKey: 'numeric-price-values',
        owner: ReferenceStructuralDelimiterOwner.deterministicVectorShape,
        renderingContract: 'keyed-deterministic-vector-shape-no-font-fallback',
      ),
    ];

final referenceTypographyAllCodePoints = <int>{
  for (final specimen in referenceTypographySpecimenStrings)
    ...specimen.runes.where((codePoint) => codePoint != 0x20),
};

final referenceTypographyExcludedStructuralCodePoints = <int>{
  for (final policy in referenceTypographyStructuralDelimiterPolicies)
    ...policy.codePoints,
};

final referenceTypographyCodePoints = Set<int>.unmodifiable(
  referenceTypographyAllCodePoints.difference(
    referenceTypographyExcludedStructuralCodePoints,
  ),
);

/// Glyphs required by the optional, separately licensed numeric-only face.
/// General and dense Roboto roles continue to require the complete corpus.
const referenceTypographyNumericSpecimenStrings = <String>[
  'XAUUSD buy 1',
  '4637.05 → 4640.81',
  '376.00  -341.00',
  '103 310.00  203.24',
];

final referenceTypographyNumericAllCodePoints = <int>{
  for (final specimen in referenceTypographyNumericSpecimenStrings)
    ...specimen.runes.where((codePoint) => codePoint != 0x20),
};

final referenceTypographyNumericCodePoints = Set<int>.unmodifiable(
  referenceTypographyNumericAllCodePoints.difference(
    referenceTypographyExcludedStructuralCodePoints,
  ),
);
