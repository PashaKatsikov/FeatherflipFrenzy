import 'dart:convert';

import '../config/flip_gate_config.dart';
import '../core/flip_models.dart';
import 'flip_agent.dart';
import 'flip_trace.dart';
import 'yard_locker.dart';

class GateDispatch {
  GateDispatch(this._agent, this._locker);

  final FlipAgent _agent;
  final YardLocker _locker;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!FlipGateConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      flipTrace(() => '[FF.COOP] dispatch ${jsonEncode(payload)}');
      final response = await _agent
          .post(
            Uri.parse(FlipGateConfig.endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: FlipGateConfig.configPostTimeoutSeconds),
          );
      flipTrace(
        () => '[FF.COOP] reply ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _locker.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      flipTrace(() => '[FF.COOP] dispatch failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
