enum FlipRoute {
  yard,
  web,
  fresh;

  String get storageValue => switch (this) {
    FlipRoute.yard => 'yard',
    FlipRoute.web => 'web',
    FlipRoute.fresh => 'fresh',
  };

  static FlipRoute parse(String? value) => switch (value) {
    'web' || 'portal' => FlipRoute.web,
    'yard' || 'native' || 'game' => FlipRoute.yard,
    _ => FlipRoute.fresh,
  };
}

class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

sealed class FlipDestination {
  const FlipDestination();
}

final class YardHome extends FlipDestination {
  const YardHome();
}

final class WebYard extends FlipDestination {
  const WebYard(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

final class QuietYard extends FlipDestination {
  const QuietYard({required this.returnToYard});

  final bool returnToYard;
}
