export type ControlPreferences = {
  density: 'comfortable' | 'compact';
  fontScale: 'normal' | 'large';
};

const STORAGE_KEY = 'sjpos.control.preferences.v1';

export const DEFAULT_CONTROL_PREFERENCES: ControlPreferences = {
  density: 'comfortable',
  fontScale: 'normal',
};

function validDensity(value: unknown): value is ControlPreferences['density'] {
  return value === 'comfortable' || value === 'compact';
}

function validFontScale(
  value: unknown,
): value is ControlPreferences['fontScale'] {
  return value === 'normal' || value === 'large';
}

export function loadControlPreferences(
  storage: Pick<Storage, 'getItem'> = window.localStorage,
): ControlPreferences {
  try {
    const raw = storage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_CONTROL_PREFERENCES;
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    return {
      density: validDensity(parsed.density)
        ? parsed.density
        : DEFAULT_CONTROL_PREFERENCES.density,
      fontScale: validFontScale(parsed.fontScale)
        ? parsed.fontScale
        : DEFAULT_CONTROL_PREFERENCES.fontScale,
    };
  } catch {
    return DEFAULT_CONTROL_PREFERENCES;
  }
}

export function applyControlPreferences(
  preferences: ControlPreferences,
  root: HTMLElement = document.documentElement,
) {
  root.setAttribute('data-sj-density', preferences.density);
  root.setAttribute('data-sj-font-scale', preferences.fontScale);
}

export function saveControlPreferences(
  preferences: ControlPreferences,
  storage: Pick<Storage, 'setItem'> = window.localStorage,
) {
  storage.setItem(STORAGE_KEY, JSON.stringify(preferences));
  applyControlPreferences(preferences);
  window.dispatchEvent(
    new CustomEvent('sj-control-preferences-changed', {
      detail: preferences,
    }),
  );
}

export function initializeControlPreferences() {
  applyControlPreferences(loadControlPreferences());
}
