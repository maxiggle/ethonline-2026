class AppConfig {
  static const String privyAppId = String.fromEnvironment(
    "PRIVY_APP_ID",
    defaultValue: "cmtxqm6nq004l0clgqp0hhtoz",
  );

  static const String privyClientId = String.fromEnvironment(
    "PRIVY_CLIENT_ID",
    defaultValue: "client-WY6d91ucEvtodyQkHGWv2VUFCbvHoyDFU91nDg3XhUvxP",
  );

  static const String privyAppScheme = String.fromEnvironment(
    "PRIVY_APP_SCHEME",
    defaultValue: "chapter2",
  );

  static const String backendBaseUrl = String.fromEnvironment(
    "BACKEND_BASE_URL",
    defaultValue: "http://localhost:3001",
  );
}
