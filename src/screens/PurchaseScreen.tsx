import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';

type PurchaseOrderRow = {
  id: string;
  order_number: string;
  status: string;
  ordered_at: string;
  expected_at: string | null;
  supplier_name: string;
  location_name: string;
};

type ReceiptRow = {
  id: string;
  receipt_number: string;
  status: string;
  received_at: string;
  posted_at: string | null;
  order_number: string | null;
  location_name: string;
};

type PayableRow = {
  payable_id: string;
  supplier_name: string;
  invoice_reference: string | null;
  original_amount: number;
  paid_amount: number;
  balance: number;
  status: string;
  created_at: string;
};

type PurchaseOverview = {
  orders: PurchaseOrderRow[];
  receipts: ReceiptRow[];
  payables: PayableRow[];
};

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

export function PurchaseScreen() {
  const [overview, setOverview] = useState<PurchaseOverview>({
    orders: [],
    receipts: [],
    payables: [],
  });
  const [error, setError] = useState('');

  useEffect(() => {
    void (async () => {
      const { data, error: loadError } = await supabase.rpc(
        'purchase_operational_overview',
      );
      if (loadError) {
        setError(loadError.message);
        return;
      }
      const value = (data ?? {}) as Partial<PurchaseOverview>;
      setOverview({
        orders: value.orders ?? [],
        receipts: value.receipts ?? [],
        payables: value.payables ?? [],
      });
    })();
  }, []);

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <p className="eyebrow">PEMBELIAN</p>
          <h1>Pembelian & Supplier</h1>
        </div>
      </header>

      {error && <p className="error-banner">{error}</p>}

      <section className="identity-card">
        <h2>Purchase Order</h2>
        {overview.orders.length === 0 ? (
          <p className="muted">Belum ada Purchase Order.</p>
        ) : (
          <div className="stack-list">
            {overview.orders.map((row) => (
              <article className="list-card" key={row.id}>
                <strong>{row.order_number}</strong>
                <span>{row.supplier_name}</span>
                <span>{row.location_name + ' - ' + row.status}</span>
              </article>
            ))}
          </div>
        )}
      </section>

      <section className="identity-card">
        <h2>Penerimaan Barang (GRN)</h2>
        {overview.receipts.length === 0 ? (
          <p className="muted">Belum ada penerimaan barang.</p>
        ) : (
          <div className="stack-list">
            {overview.receipts.map((row) => (
              <article className="list-card" key={row.id}>
                <strong>{row.receipt_number}</strong>
                <span>{row.order_number ?? 'Tanpa PO'}</span>
                <span>{row.location_name + ' - ' + row.status}</span>
              </article>
            ))}
          </div>
        )}
      </section>

      <section className="identity-card">
        <h2>Utang Pemasok</h2>
        {overview.payables.length === 0 ? (
          <p className="muted">Belum ada utang pemasok.</p>
        ) : (
          <div className="stack-list">
            {overview.payables.map((row) => (
              <article className="list-card" key={row.payable_id}>
                <strong>{row.supplier_name}</strong>
                <span>
                  {row.invoice_reference ?? 'Tanpa referensi invoice'}
                </span>
                <span>
                  Sisa {formatIdr(Number(row.balance))} - {row.status}
                </span>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
