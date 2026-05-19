/// App state resolver — provides tools with a stable way to obtain [IAppState]
/// regardless of how GetX resolves abstract vs concrete types.
///
/// Problem: GetX controller lookup is keyed by the **exact** runtime type that
/// was passed to [Get.put]. Registering an [AppController] instance under the
/// abstract [IAppState] type causes GetX to silently fail in some versions
/// because abstract classes cannot be instantiated and GetX's internal type
/// checks reject them.
///
/// Solution: always register and find the concrete [AppController], then
/// return it through the [IAppState] interface. Tools call [appState()] and
/// never interact with [AppController] directly — the architectural boundary
/// is preserved at the call-site level.
library;

import 'package:get/get.dart';
import '../controllers/i_app_state.dart';
import '../controllers/app_controller.dart';

/// Resolve the active [IAppState] from the GetX service locator.
///
/// Tries [IAppState] first (works if explicitly double-registered in main.dart),
/// then falls back to [AppController] which is always registered.
/// Throws [StateError] if neither is found — which means startup is broken.
IAppState appState() {
  if (GetInstance().isRegistered<IAppState>()) {
    return Get.find<IAppState>();
  }
  if (GetInstance().isRegistered<AppController>()) {
    return Get.find<AppController>();
  }
  throw StateError(
    'No IAppState implementation registered. '
    'Ensure AppController is registered via Get.put() before tools execute.',
  );
}
