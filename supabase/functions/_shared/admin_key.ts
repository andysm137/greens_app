export function resolveAdminKey(
  secretKeys: string | undefined,
  legacyKey: string | undefined,
): string | undefined {
  if (legacyKey) return legacyKey;
  if (!secretKeys) return undefined;

  try {
    const parsed = JSON.parse(secretKeys) as Record<string, unknown>;
    const values = Object.values(parsed).filter(
      (value): value is string => typeof value === "string",
    );
    return values.find((value) => value.startsWith("sb_secret_")) ?? values[0];
  } catch (_) {
    return secretKeys;
  }
}
