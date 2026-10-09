import type { ProductionOverview } from '../../../src/production/production-api';

const batches: ProductionOverview['batches'] = Array.from(
  { length: 24 },
  (_, index) => ({
    id: `fixture-batch-${index + 1}`,
    locationId: 'fixture-store',
    locationName: 'Gerai Contoh',
    finishedGoodId: 'fixture-good',
    finishedGoodName: 'BAKARAN CONTOH',
    finishedGoodCode: 'CONTOH-01',
    baseUnit: 'pcs',
    bomId: 'fixture-bom',
    bomVersion: 1,
    plannedOutput: 20 + index,
    actualOutput: index >= 16 ? 20 + index : null,
    status: index >= 16 ? ('POSTED' as const) : ('DRAFT' as const),
    createdAt: '2026-10-08T10:00:00+07:00',
    postedAt: index >= 16 ? '2026-10-08T12:00:00+07:00' : null,
  }),
);

export async function fetchProductionOverview(): Promise<ProductionOverview> {
  return {
    locations: [
      {
        id: 'fixture-store',
        code: 'GERAI',
        displayName: 'Gerai Contoh',
        locationType: 'STORE',
      },
    ],
    finishedGoods: [
      {
        id: 'fixture-good',
        code: 'CONTOH-01',
        displayName: 'BAKARAN CONTOH',
        baseUnit: 'pcs',
      },
    ],
    activeBoms: [
      {
        id: 'fixture-bom',
        finishedGoodId: 'fixture-good',
        version: 1,
        yieldQuantity: 20,
      },
    ],
    batches,
  };
}

export async function createProductionBatch(): Promise<never> {
  throw new Error('Fixture visual: posting batch dinonaktifkan');
}
export async function postProductionBatch(): Promise<never> {
  throw new Error('Fixture visual: posting produksi dinonaktifkan');
}
