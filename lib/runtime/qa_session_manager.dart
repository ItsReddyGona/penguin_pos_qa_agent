import 'dart:io';
import 'dart:collection';
import 'dart:math';

import 'package:penguin_pos_qa_agent/runtime/app_launcher.dart';
import 'package:penguin_pos_qa_agent/runtime/qa_profile_config.dart';

class QaSession {
  const QaSession({
    required this.id,
    required this.vmServiceUri,
    required this.profile,
    this.launchedApp,
  });

  final String id;
  final Uri vmServiceUri;
  final QaProfile profile;
  final LaunchedPenguinPos? launchedApp;
}

/// Owns application lifecycle across MCP tool calls in one stdio connection.
class QaSessionManager {
  QaSessionManager({required PenguinPosAppLauncher launcher})
    : _launcher = launcher;

  final PenguinPosAppLauncher _launcher;
  final Map<String, QaSession> _sessions = HashMap<String, QaSession>();
  final Random _random = Random.secure();

  Future<QaSession> start({
    String? profileName,
    String? vmServiceUri,
    String? appRoot,
    String? device,
  }) async {
    final profile = QaProfileConfig.resolve(profileName);
    final suppliedUri = vmServiceUri == null
        ? null
        : Uri.tryParse(vmServiceUri);
    if (vmServiceUri != null && suppliedUri == null) {
      throw ArgumentError('vm_service_uri is not a valid URI.');
    }
    LaunchedPenguinPos? launched;
    final uri =
        suppliedUri ??
        (launched = await _launcher.launch(
          appRoot:
              appRoot ??
              Platform.environment['PENGUIN_POS_ROOT'] ??
              PenguinPosAppLauncher.defaultAppRoot,
          device: device,
          entity: profile.entity,
          env: profile.env,
        )).vmServiceUri;
    final session = QaSession(
      id: _newSessionId(),
      vmServiceUri: uri,
      profile: profile,
      launchedApp: launched,
    );
    _sessions[session.id] = session;
    return session;
  }

  QaSession requireSession(String id) {
    final session = _sessions[id];
    if (session == null) {
      throw ArgumentError('Unknown or closed qa_session_id: $id.');
    }
    return session;
  }

  Future<bool> stop(String id) async {
    final session = _sessions.remove(id);
    if (session == null) return false;
    await session.launchedApp?.close();
    return true;
  }

  Future<void> closeAll() async {
    final ids = _sessions.keys.toList();
    for (final id in ids) {
      await stop(id);
    }
  }

  String _newSessionId() => List<String>.generate(
    16,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
}
