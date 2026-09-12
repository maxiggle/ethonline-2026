
import 'agent_security_platform_interface.dart';

class AgentSecurity {
  Future<String?> getPlatformVersion() {
    return AgentSecurityPlatform.instance.getPlatformVersion();
  }
}
