enum GuardianVerdict {
  allow,
  escalate,
  block;

  String get label {
    switch (this) {
      case GuardianVerdict.allow:
        return 'ALLOW';
      case GuardianVerdict.escalate:
        return 'ESCALATE';
      case GuardianVerdict.block:
        return 'BLOCK';
    }
  }

  bool get isAllowed => this == GuardianVerdict.allow;
  bool get isEscalated => this == GuardianVerdict.escalate;
  bool get isBlocked => this == GuardianVerdict.block;
}
