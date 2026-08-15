import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/horse.dart';

class HorsesNotifier extends Notifier<List<Horse>> {
  @override
  List<Horse> build() => [];

  void add(Horse horse) => state = [...state, horse];

  void replaceAt(int index, Horse horse) {
    final copy = List<Horse>.from(state);
    copy[index] = horse;
    state = copy;
  }

  void removeAt(int index) {
    final copy = List<Horse>.from(state)..removeAt(index);
    state = copy;
  }

  void clear() => state = [];
}

final horsesProvider = NotifierProvider<HorsesNotifier, List<Horse>>(HorsesNotifier.new);
