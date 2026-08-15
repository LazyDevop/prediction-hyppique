import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engine_params.dart';

class EngineParamsNotifier extends Notifier<EngineParams> {
  @override
  EngineParams build() => const EngineParams();

  void update(EngineParams params) => state = params;
}

final engineParamsProvider = NotifierProvider<EngineParamsNotifier, EngineParams>(EngineParamsNotifier.new);
