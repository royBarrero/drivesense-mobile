/// URL del backend. Se cambia con `--dart-define=API_URL=...`.
/// Por defecto 127.0.0.1, pensado para `adb reverse tcp:8000 tcp:8000`.
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://127.0.0.1:8000',
);
