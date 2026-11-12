import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/call_repository.dart';
import '../models/call_dto.dart';

class ApiCallRepository implements CallRepository {
  ApiCallRepository(this._client);

  final ApiClient _client;

  @override
  Future<CallStartResult> start({
    required String conversationId,
    required CallType type,
  }) async => CallStartResultDto.fromJson(
    asJson(
      await _client.post(
        ApiEndpoints.calls,
        body: {
          'conversationId': conversationId,
          'type': CallDto.typeWire(type),
        },
      ),
    ),
  );

  @override
  Future<CallAcceptResult> accept(String callId) async =>
      CallAcceptResultDto.fromJson(
        asJson(await _client.post(ApiEndpoints.callAccept(callId))),
      );

  @override
  Future<CallSession> reject(String callId) async => CallDto.fromJson(
    asJson(await _client.post(ApiEndpoints.callReject(callId))),
  );

  @override
  Future<CallSession> cancel(String callId) async => CallDto.fromJson(
    asJson(await _client.post(ApiEndpoints.callCancel(callId))),
  );

  @override
  Future<CallSession> end(String callId) async => CallDto.fromJson(
    asJson(await _client.post(ApiEndpoints.callEnd(callId))),
  );

  @override
  Future<ActiveCallSnapshot> getActive() async => ActiveCallSnapshotDto.fromJson(
    asJson(await _client.get(ApiEndpoints.callsActive)),
  );

  @override
  Future<List<CallSession>> listHistory({int limit = 20}) async {
    final clamped = limit.clamp(1, 50);
    final data = asJson(
      await _client.get(ApiEndpoints.calls, query: {'limit': clamped}),
    );
    return [
      for (final item in asJsonList(data['items'], 'items'))
        CallDto.fromJson(item),
    ];
  }
}
