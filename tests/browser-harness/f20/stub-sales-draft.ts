import type { PendingCheckoutDraft } from '../../../src/sales/sales-draft';
// No localStorage changes in UI fixture; no business write or persisted draft.
export type { PendingCheckoutDraft };
export function loadSalesDraft(): null {
  return null;
}
export function saveSalesDraft(): void {}
export function clearSalesDraft(): void {}
export function hasSalesDraftForProfile(): boolean {
  return false;
}
