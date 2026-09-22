export function currentConnectivity(): 'ONLINE' | 'OFFLINE' {
  if (typeof navigator === 'undefined') return 'ONLINE';
  return navigator.onLine ? 'ONLINE' : 'OFFLINE';
}
