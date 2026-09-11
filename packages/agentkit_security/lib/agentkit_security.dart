
import 'agentkit_security_platform_interface.dart';

class AgentkitSecurity {
  Future<String?> getPlatformVersion() {
    return AgentkitSecurityPlatform.instance.getPlatformVersion();
  }
}
