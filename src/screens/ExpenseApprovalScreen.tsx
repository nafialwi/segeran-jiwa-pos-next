import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { requireOnlineAction } from '../health/online-action';

type ApprovalRule = {
  id: string;
  category_code: string;
  min_amount: number;
  active: boolean;
};

type ApprovalRequest = {
  request_id: string;
  actor_profile_id: string;
  category_code: string;
  description: string;
  amount: number;
  requested_at: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  decision_reason: string | null;
};

function formatIdr(value: number): string {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

export function ExpenseApprovalScreen() {
  const [rules, setRules] = useState<ApprovalRule[]>([]);
  const [requests, setRequests] = useState<ApprovalRequest[]>([]);
  const [category, setCategory] = useState('*');
  const [minAmount, setMinAmount] = useState(0);
  const [active, setActive] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');

  const load = useCallback(async () => {
    const [ruleResult, requestResult] = await Promise.all([
      supabase
        .from('expense_approval_rules')
        .select('id,category_code,min_amount,active')
        .order('category_code'),
      supabase
        .from('expense_approval_queue')
        .select(
          'request_id,actor_profile_id,category_code,description,amount,requested_at,status,decision_reason',
        )
        .order('requested_at', { ascending: false }),
    ]);

    if (ruleResult.error) throw new Error(ruleResult.error.message);
    if (requestResult.error) throw new Error(requestResult.error.message);

    setRules((ruleResult.data ?? []) as ApprovalRule[]);
    setRequests((requestResult.data ?? []) as ApprovalRequest[]);
  }, []);

  useEffect(() => {
    void load().catch((error: unknown) => {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Data approval pengeluaran tidak dapat dimuat.',
      );
    });
  }, [load]);

  async function saveRule(event: React.FormEvent) {
    event.preventDefault();
    requireOnlineAction('Perubahan rule approval');
    setBusy(true);
    setMessage('');
    try {
      const { error } = await supabase.rpc(
        'finance_set_expense_approval_rule',
        {
          p_category_code: category,
          p_min_amount: minAmount,
          p_active: active,
        },
      );
      if (error) throw new Error(error.message);
      setMessage('Rule approval tersimpan.');
      await load();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Rule approval gagal disimpan.',
      );
    } finally {
      setBusy(false);
    }
  }

  async function decide(requestId: string, approve: boolean) {
    requireOnlineAction('Keputusan approval pengeluaran');
    const reason = approve
      ? (window.prompt('Catatan approval (opsional):', '') ?? '')
      : (window.prompt('Alasan penolakan (opsional):', '') ?? '');

    setBusy(true);
    setMessage('');
    try {
      const { error } = await supabase.rpc('finance_decide_expense_request', {
        p_request_id: requestId,
        p_approve: approve,
        p_reason: reason,
        p_idempotency_key: crypto.randomUUID(),
      });
      if (error) throw new Error(error.message);
      setMessage(approve ? 'Pengeluaran disetujui.' : 'Pengeluaran ditolak.');
      await load();
    } catch (error) {
      setMessage(
        error instanceof Error
          ? error.message
          : 'Keputusan approval tidak dapat disimpan.',
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <Link className="muted" to="/">
            Kembali ke Beranda
          </Link>
          <h1>Approval Pengeluaran</h1>
        </div>
      </header>

      {message && <p className="error-banner">{message}</p>}

      <section className="identity-card">
        <h2>Aturan Approval</h2>
        <p className="muted">
          Gunakan * untuk semua kategori, atau isi kode kategori tertentu.
        </p>
        <form className="stack-form" onSubmit={saveRule}>
          <label>
            Kategori
            <input
              value={category}
              onChange={(event) => setCategory(event.target.value)}
              placeholder="* atau OPERASIONAL"
              required
            />
          </label>
          <label>
            Minimal Nominal (Rp)
            <input
              type="number"
              min="0"
              step="1000"
              value={minAmount}
              onChange={(event) => setMinAmount(Number(event.target.value))}
              required
            />
          </label>
          <label className="radio-row">
            <input
              type="checkbox"
              checked={active}
              onChange={(event) => setActive(event.target.checked)}
            />
            Rule aktif
          </label>
          <button className="primary-button" type="submit" disabled={busy}>
            {busy ? 'Menyimpan...' : 'Simpan Rule'}
          </button>
        </form>

        {rules.length > 0 && (
          <div className="stack-list">
            {rules.map((rule) => (
              <article className="list-card" key={rule.id}>
                <strong>{rule.category_code}</strong>
                <span>Mulai {formatIdr(rule.min_amount)}</span>
                <span>{rule.active ? 'Aktif' : 'Nonaktif'}</span>
              </article>
            ))}
          </div>
        )}
      </section>

      <section className="identity-card">
        <h2>Permintaan Pengeluaran</h2>
        {requests.length === 0 ? (
          <p className="muted">Belum ada permintaan approval.</p>
        ) : (
          <div className="stack-list">
            {requests.map((request) => (
              <article className="list-card" key={request.request_id}>
                <strong>
                  {request.category_code} - {formatIdr(request.amount)}
                </strong>
                <span>{request.description}</span>
                <span>Status: {request.status}</span>
                <span>
                  {new Date(request.requested_at).toLocaleString('id-ID')}
                </span>
                {request.decision_reason && (
                  <span>Catatan: {request.decision_reason}</span>
                )}
                {request.status === 'PENDING' && (
                  <div className="button-row">
                    <button
                      className="primary-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void decide(request.request_id, true)}
                    >
                      Setujui
                    </button>
                    <button
                      className="secondary-button"
                      type="button"
                      disabled={busy}
                      onClick={() => void decide(request.request_id, false)}
                    >
                      Tolak
                    </button>
                  </div>
                )}
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
