import '../../logger/app_logger.dart';
import '../../observability/crash_reporter.dart';

class MigrationReporter {
  const MigrationReporter(this.logger, this.crashReporter);

  final AppLogger logger;
  final CrashReporter crashReporter;

  Never report(Object error, StackTrace stackTrace, int from, int to) {
    logger.error(
      'Database migration failed from v$from to v$to',
      error,
      stackTrace,
    );
    crashReporter.record(
      error,
      stackTrace,
      context: {'from_schema': from, 'to_schema': to},
    );
    Error.throwWithStackTrace(error, stackTrace);
  }
}
