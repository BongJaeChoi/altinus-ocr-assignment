import '../../../src/generated/platform_apis.g.dart';
import '../domain/ocr_ports.dart';

abstract interface class SettingsGateway {
  Future<bool> open();
}

final class PigeonSettingsGateway implements SettingsGateway {
  PigeonSettingsGateway({AppSettingsHostApi? api})
    : _api = api ?? AppSettingsHostApi();

  final AppSettingsHostApi _api;

  @override
  Future<bool> open() => _api.open();
}

final class PigeonAppSettingsLauncher implements AppSettingsLauncher {
  PigeonAppSettingsLauncher({SettingsGateway? gateway})
    : _gateway = gateway ?? PigeonSettingsGateway();

  final SettingsGateway _gateway;

  @override
  Future<bool> open() => _gateway.open();
}
