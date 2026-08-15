import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/api_client.dart';
import '../repository/course_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(apiClientProvider)),
);
