import type { CSSProperties } from 'react';
import { resolveIconPath, type SegeranIconName } from './iconRegistry';

type IconProps = {
  name: SegeranIconName;
  active?: boolean;
  size?: number;
  className?: string;
  label?: string;
};

export function Icon({
  name,
  active = false,
  size = 24,
  className = '',
  label,
}: IconProps) {
  const source = resolveIconPath(name, active);
  const style = {
    '--sj-icon-url': `url("${source}")`,
    width: size,
    height: size,
  } as CSSProperties;

  return (
    <span
      className={`sj-icon ${className}`.trim()}
      style={style}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    />
  );
}
