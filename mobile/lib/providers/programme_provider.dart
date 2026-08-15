import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_summary.dart';
import 'api_provider.dart';

final programmeProvider = FutureProvider.family<List<CourseSummary>, DateTime>((ref, date) {
  return ref.watch(courseRepositoryProvider).programmeDuJour(date);
});
