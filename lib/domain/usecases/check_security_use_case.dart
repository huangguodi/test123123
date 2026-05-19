import '../../core/security/security_service.dart';

class CheckSecurityUseCase {
  final SecurityService _securityService;

  CheckSecurityUseCase(this._securityService);

  Future<bool> execute() async {
    return await _securityService.isDeviceSafe();
  }
}
