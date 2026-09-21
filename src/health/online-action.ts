export function browserIsOnline(): boolean {
  if (typeof navigator === 'undefined') return true;
  return navigator.onLine;
}

export function requireOnlineAction(
  action: string,
  isOnline: boolean = browserIsOnline(),
): void {
  if (isOnline) return;

  throw new Error(
    action + ' memerlukan koneksi internet aktif dan tidak diantrikan offline.',
  );
}
