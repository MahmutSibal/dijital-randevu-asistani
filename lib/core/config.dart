/// Default backend (WebAppointment.Api) address. On the Android emulator,
/// 10.0.2.2 is the host machine's loopback. Override at build time with
/// `--dart-define=API_BASE_URL=http://192.168.1.10:5233`.
const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5233',
);
