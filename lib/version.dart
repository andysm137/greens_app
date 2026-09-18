/// App version: MAJOR.MINOR.RELEASE
/// MAJOR = production version, MINOR = new feature addition, RELEASE = codebase update.
const String kAppVersion = '0.10.200';

/// Short git commit hash, injected at build time via
/// `--dart-define=GIT_COMMIT=$(git rev-parse --short HEAD)`.
/// Falls back to 'dev' for local builds that don't set it.
const String kAppGitCommit = String.fromEnvironment(
  'GIT_COMMIT',
  defaultValue: 'dev',
);
