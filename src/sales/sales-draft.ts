import type {
  SaleDiscountType,
  SalePaymentMethod,
} from './sales-api';

export type SalesDraftLine = {
  variantId: string;
  quantity: number;
  lineNote: string;
};

export type PendingCheckoutDraft = {
  operationId: string;
  locationId: string;
  items: Array<{
    variant_id: string;
    quantity: number;
    line_note?: string;
  }>;
  method: SalePaymentMethod;
  total: number;
  tenderedAmount?: number;
  discount: {
    type: SaleDiscountType;
    value: number;
    reason?: string;
  };
  customerId?: string;
  note?: string;
};

export type SalesDraft = {
  version: 1;
  profileId: string;
  shiftId: string;
  lines: SalesDraftLine[];
  method: SalePaymentMethod;
  cashReceived: number;
  customerId: string;
  note: string;
  discountType: SaleDiscountType;
  discountValue: number;
  discountReason: string;
  pendingCheckout: PendingCheckoutDraft | null;
};

export type SalesDraftInput = Omit<SalesDraft, 'version'>;

type DraftStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;

const STORAGE_PREFIX = 'sj.sales.draft.v1';
const PAYMENT_METHODS: SalePaymentMethod[] = [
  'CASH',
  'QRIS',
  'TRANSFER',
  'CREDIT',
];
const DISCOUNT_TYPES: SaleDiscountType[] = ['NONE', 'AMOUNT', 'PERCENT'];

function storageKey(profileId: string, shiftId: string): string {
  return STORAGE_PREFIX + ':' + profileId + ':' + shiftId;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function validLine(value: unknown): value is SalesDraftLine {
  if (!isRecord(value)) return false;
  return (
    typeof value.variantId === 'string' &&
    value.variantId.length > 0 &&
    Number.isInteger(value.quantity) &&
    Number(value.quantity) > 0 &&
    typeof value.lineNote === 'string'
  );
}

function validPendingCheckout(value: unknown): value is PendingCheckoutDraft {
  if (!isRecord(value)) return false;
  if (
    typeof value.operationId !== 'string' ||
    value.operationId.length === 0 ||
    typeof value.locationId !== 'string' ||
    value.locationId.length === 0 ||
    !PAYMENT_METHODS.includes(value.method as SalePaymentMethod) ||
    !isFiniteNumber(value.total) ||
    !Array.isArray(value.items) ||
    !isRecord(value.discount)
  ) {
    return false;
  }

  if (
    !DISCOUNT_TYPES.includes(value.discount.type as SaleDiscountType) ||
    !isFiniteNumber(value.discount.value)
  ) {
    return false;
  }

  if (
    value.tenderedAmount !== undefined &&
    !isFiniteNumber(value.tenderedAmount)
  ) {
    return false;
  }
  if (value.customerId !== undefined && typeof value.customerId !== 'string') {
    return false;
  }
  if (value.note !== undefined && typeof value.note !== 'string') {
    return false;
  }
  if (
    value.discount.reason !== undefined &&
    typeof value.discount.reason !== 'string'
  ) {
    return false;
  }

  return value.items.every((item) => {
    if (!isRecord(item)) return false;
    return (
      typeof item.variant_id === 'string' &&
      item.variant_id.length > 0 &&
      Number.isInteger(item.quantity) &&
      Number(item.quantity) > 0 &&
      (item.line_note === undefined || typeof item.line_note === 'string')
    );
  });
}

export function loadSalesDraft(
  storage: DraftStorage,
  profileId: string,
  shiftId: string,
): SalesDraft | null {
  let raw: string | null = null;
  try {
    raw = storage.getItem(storageKey(profileId, shiftId));
  } catch {
    return null;
  }
  if (!raw) return null;

  try {
    const value: unknown = JSON.parse(raw);
    if (!isRecord(value)) return null;
    if (
      value.version !== 1 ||
      value.profileId !== profileId ||
      value.shiftId !== shiftId ||
      !Array.isArray(value.lines) ||
      !value.lines.every(validLine) ||
      !PAYMENT_METHODS.includes(value.method as SalePaymentMethod) ||
      !isFiniteNumber(value.cashReceived) ||
      typeof value.customerId !== 'string' ||
      typeof value.note !== 'string' ||
      !DISCOUNT_TYPES.includes(value.discountType as SaleDiscountType) ||
      !isFiniteNumber(value.discountValue) ||
      typeof value.discountReason !== 'string' ||
      !(
        value.pendingCheckout === null ||
        validPendingCheckout(value.pendingCheckout)
      )
    ) {
      return null;
    }

    return value as SalesDraft;
  } catch {
    return null;
  }
}

export function saveSalesDraft(
  storage: DraftStorage,
  draft: SalesDraftInput,
): void {
  const value: SalesDraft = { version: 1, ...draft };
  try {
    storage.setItem(
      storageKey(draft.profileId, draft.shiftId),
      JSON.stringify(value),
    );
  } catch {
    // Draft continuity is best-effort and must never block a live sale.
  }
}

export function clearSalesDraft(
  storage: DraftStorage,
  profileId: string,
  shiftId: string,
): void {
  try {
    storage.removeItem(storageKey(profileId, shiftId));
  } catch {
    // Clearing a stale draft must never block checkout completion.
  }
}


export function hasSalesDraftForProfile(
  storage: Storage,
  profileId: string,
): boolean {
  const prefix = STORAGE_PREFIX + ':' + profileId + ':';
  try {
    for (let index = 0; index < storage.length; index += 1) {
      const key = storage.key(index);
      if (key?.startsWith(prefix) && storage.getItem(key)) {
        return true;
      }
    }
  } catch {
    return false;
  }
  return false;
}
