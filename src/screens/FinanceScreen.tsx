import { FormEvent, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ControlCenterNav } from '../components/ControlCenterNav';
import {
  createEmployeeKasbon,
  fetchFinanceOverview,
  payCustomerDebt,
  paySupplierPayable,
  postFinanceTransfer,
  postOwnerCapital,
  postOwnerPersonalWithdrawal,
  reconcileFinanceDay,
  settleQris,
  type FinanceOverview,
} from '../finance/finance-api';

function formatIdr(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}

function localDate() {
  const now = new Date();
  const local = new Date(now.getTime() - now.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}

function positiveAmount(value: string) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error('Jumlah harus lebih dari Rp0.');
  }
  return amount;
}

export function FinanceScreen() {
  const [overview, setOverview] = useState<FinanceOverview | null>(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [busy, setBusy] = useState('');

  const [transfer, setTransfer] = useState({
    from: '',
    to: '',
    amount: '',
    reason: 'PINDAH_UANG',
  });
  const [capital, setCapital] = useState({
    to: '',
    amount: '',
    reason: 'SETOR_MODAL',
  });
  const [personal, setPersonal] = useState({
    from: '',
    amount: '',
    reason: 'PENGELUARAN_PRIBADI',
  });
  const [qris, setQris] = useState({
    date: localDate(),
    reference: '',
    gross: '',
    fee: '0',
  });
  const [recon, setRecon] = useState({
    date: localDate(),
    countedCash: '',
    bankTransferReceived: '',
    stockStatus: 'NOT_CHECKED' as 'SESUAI' | 'PERLU_DIPERIKSA' | 'NOT_CHECKED',
  });
  const [debtPayment, setDebtPayment] = useState({
    debtId: '',
    method: 'CASH' as 'CASH' | 'TRANSFER',
    amount: '',
  });
  const [supplierPayment, setSupplierPayment] = useState({
    payableId: '',
    method: 'CASH' as 'CASH' | 'TRANSFER',
    amount: '',
  });
  const [kasbon, setKasbon] = useState({
    employeeProfileId: '',
    sourceMethod: 'CASH' as 'CASH' | 'TRANSFER',
    amount: '',
    note: '',
  });

  async function load() {
    setError('');
    try {
      setOverview(await fetchFinanceOverview());
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : 'Gagal memuat Keuangan.',
      );
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const liquidAccounts = useMemo(
    () =>
      (overview?.accounts ?? []).filter((account) =>
        ['KAS_UTAMA', 'KAS_SHIFT', 'BANK'].includes(account.code),
      ),
    [overview],
  );
  const ownerCashAccounts = useMemo(
    () =>
      (overview?.accounts ?? []).filter((account) =>
        ['KAS_UTAMA', 'BANK'].includes(account.code),
      ),
    [overview],
  );
  const employeeOptions = useMemo(
    () =>
      (overview?.employees ?? []).filter(
        (employee) => employee.role_code !== 'OWNER',
      ),
    [overview],
  );

  async function run(label: string, action: () => Promise<unknown>) {
    if (busy) return;
    setBusy(label);
    setError('');
    setSuccess('');
    try {
      await action();
      await load();
      setSuccess(label + ' berhasil dicatat.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : label + ' gagal.');
    } finally {
      setBusy('');
    }
  }

  function submitTransfer(event: FormEvent) {
    event.preventDefault();
    void run('Pindah Uang', async () => {
      if (!transfer.from || !transfer.to || transfer.from === transfer.to) {
        throw new Error('Pilih akun sumber dan tujuan yang berbeda.');
      }
      await postFinanceTransfer({
        fromAccountId: transfer.from,
        toAccountId: transfer.to,
        amount: positiveAmount(transfer.amount),
        reason: transfer.reason.trim() || 'PINDAH_UANG',
      });
      setTransfer((value) => ({ ...value, amount: '' }));
    });
  }

  function submitCapital(event: FormEvent) {
    event.preventDefault();
    void run('Modal Owner', async () => {
      if (!capital.to) throw new Error('Pilih tujuan modal.');
      await postOwnerCapital({
        toAccountId: capital.to,
        amount: positiveAmount(capital.amount),
        reason: capital.reason.trim() || 'SETOR_MODAL',
      });
      setCapital((value) => ({ ...value, amount: '' }));
    });
  }

  function submitPersonal(event: FormEvent) {
    event.preventDefault();
    if (
      !window.confirm(
        'Pengeluaran Pribadi Owner tidak diperlakukan sebagai biaya usaha dan tidak mengurangi laba usaha. Lanjutkan?',
      )
    ) {
      return;
    }
    void run('Pengeluaran Pribadi Owner', async () => {
      if (!personal.from) throw new Error('Pilih sumber dana pribadi.');
      await postOwnerPersonalWithdrawal({
        fromAccountId: personal.from,
        amount: positiveAmount(personal.amount),
        reason: personal.reason.trim() || 'PENGELUARAN_PRIBADI',
      });
      setPersonal((value) => ({ ...value, amount: '' }));
    });
  }

  function submitQris(event: FormEvent) {
    event.preventDefault();
    void run('Settlement QRIS', async () => {
      await settleQris({
        settlementDate: qris.date,
        providerReference: qris.reference.trim(),
        grossAmount: positiveAmount(qris.gross),
        providerFee: Number(qris.fee || 0),
      });
      setQris((value) => ({ ...value, reference: '', gross: '', fee: '0' }));
    });
  }

  function submitReconciliation(event: FormEvent) {
    event.preventDefault();
    void run('Rekonsiliasi Harian', async () => {
      await reconcileFinanceDay({
        businessDate: recon.date,
        countedCash: Number(recon.countedCash || 0),
        bankTransferReceived: Number(recon.bankTransferReceived || 0),
        stockStatus: recon.stockStatus,
      });
    });
  }

  function submitDebtPayment(event: FormEvent) {
    event.preventDefault();
    void run('Pembayaran Hutang Pelanggan', async () => {
      if (!debtPayment.debtId) throw new Error('Pilih Hutang Pelanggan.');
      await payCustomerDebt({
        debtId: debtPayment.debtId,
        method: debtPayment.method,
        amount: positiveAmount(debtPayment.amount),
      });
      setDebtPayment((value) => ({ ...value, amount: '' }));
    });
  }

  function submitSupplierPayment(event: FormEvent) {
    event.preventDefault();
    void run('Pembayaran Utang Pemasok', async () => {
      if (!supplierPayment.payableId) throw new Error('Pilih Utang Pemasok.');
      await paySupplierPayable({
        payableId: supplierPayment.payableId,
        method: supplierPayment.method,
        amount: positiveAmount(supplierPayment.amount),
      });
      setSupplierPayment((value) => ({ ...value, amount: '' }));
    });
  }

  function submitKasbon(event: FormEvent) {
    event.preventDefault();
    void run('Kasbon Karyawan', async () => {
      if (!kasbon.employeeProfileId) throw new Error('Pilih karyawan.');
      await createEmployeeKasbon({
        employeeProfileId: kasbon.employeeProfileId,
        sourceMethod: kasbon.sourceMethod,
        amount: positiveAmount(kasbon.amount),
        note: kasbon.note,
      });
      setKasbon((value) => ({ ...value, amount: '', note: '' }));
    });
  }

  return (
    <main className="shell secondary-screen finance-workspace">
      <header className="topbar secondary-hero">
        <div>
          <Link to="/pengaturan">Kembali ke Pusat Kontrol</Link>
          <p className="eyebrow">OWNER FINANCE</p>
          <h1>Keuangan</h1>
        </div>
      </header>

      <ControlCenterNav />

      {error && <div className="error-banner">{error}</div>}
      {success && <div className="success-banner">{success}</div>}

      <nav className="secondary-workflow-nav" aria-label="Alur Keuangan">
        <a href="#finance-balances">Ringkasan</a>
        <a href="#finance-transfer">Pindah Uang</a>
        <a href="#finance-qris">QRIS</a>
        <a href="#finance-reconciliation">Rekonsiliasi</a>
        <a href="#finance-receivables">Piutang & Utang</a>
        <a href="#finance-kasbon">Kasbon</a>
        <a href="#finance-owner">Owner</a>
      </nav>

      <section className="identity-card secondary-panel" id="finance-balances">
        <div>
          <h2>Saldo Keuangan</h2>
          <p className="muted">
            Satu sumber kebenaran dari money ledger. Pindah uang tidak dihitung
            sebagai pemasukan atau pengeluaran baru.
          </p>
        </div>
        <div className="list-cards">
          {(overview?.accounts ?? []).map((account) => (
            <article className="list-card" key={account.id}>
              <strong>{account.display_name}</strong>
              <span className="muted">{account.code}</span>
              <strong>{formatIdr(account.balance)}</strong>
            </article>
          ))}
        </div>
      </section>

      <section className="identity-card secondary-panel" id="finance-transfer">
        <div>
          <h2>Pindah Uang</h2>
          <p className="muted">Kas Utama, Kas Shift, dan Bank.</p>
        </div>
        <form className="stack-form" onSubmit={submitTransfer}>
          <label className="field-label">
            Dari
            <select
              value={transfer.from}
              onChange={(event) =>
                setTransfer((value) => ({ ...value, from: event.target.value }))
              }
              required
            >
              <option value="">Pilih sumber</option>
              {liquidAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.display_name} · {formatIdr(account.balance)}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Ke
            <select
              value={transfer.to}
              onChange={(event) =>
                setTransfer((value) => ({ ...value, to: event.target.value }))
              }
              required
            >
              <option value="">Pilih tujuan</option>
              {liquidAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.display_name}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={transfer.amount}
              onChange={(event) =>
                setTransfer((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Keterangan
            <input
              value={transfer.reason}
              onChange={(event) =>
                setTransfer((value) => ({
                  ...value,
                  reason: event.target.value,
                }))
              }
              required
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Simpan Pindah Uang
          </button>
        </form>
      </section>

      <section className="identity-card secondary-panel" id="finance-owner">
        <div>
          <h2>Modal Owner</h2>
          <p className="muted">
            Penambahan modal menambah aset usaha, tetapi bukan pendapatan
            operasional.
          </p>
        </div>
        <form className="stack-form" onSubmit={submitCapital}>
          <label className="field-label">
            Masuk ke
            <select
              value={capital.to}
              onChange={(event) =>
                setCapital((value) => ({ ...value, to: event.target.value }))
              }
              required
            >
              <option value="">Pilih akun</option>
              {ownerCashAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.display_name}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={capital.amount}
              onChange={(event) =>
                setCapital((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Keterangan
            <input
              value={capital.reason}
              onChange={(event) =>
                setCapital((value) => ({
                  ...value,
                  reason: event.target.value,
                }))
              }
              required
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Catat Modal Owner
          </button>
        </form>
      </section>

      <section className="identity-card secondary-panel" id="finance-qris">
        <div>
          <h2>Settlement QRIS</h2>
          <p className="muted">
            QRIS Belum Cair settlement! Bank. Biaya provider dicatat terpisah.
          </p>
        </div>
        <form className="stack-form" onSubmit={submitQris}>
          <label className="field-label">
            Tanggal
            <input
              type="date"
              max={localDate()}
              value={qris.date}
              onChange={(event) =>
                setQris((value) => ({ ...value, date: event.target.value }))
              }
              required
            />
          </label>
          <label className="field-label">
            Referensi provider
            <input
              value={qris.reference}
              onChange={(event) =>
                setQris((value) => ({
                  ...value,
                  reference: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Gross (Rp)
            <input
              type="number"
              min="1"
              value={qris.gross}
              onChange={(event) =>
                setQris((value) => ({ ...value, gross: event.target.value }))
              }
              required
            />
          </label>
          <label className="field-label">
            Biaya provider (Rp)
            <input
              type="number"
              min="0"
              value={qris.fee}
              onChange={(event) =>
                setQris((value) => ({ ...value, fee: event.target.value }))
              }
              required
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Catat Settlement QRIS
          </button>
        </form>
        {(overview?.qrisSettlements ?? []).length > 0 && (
          <div className="stack-list">
            {overview?.qrisSettlements.map((item) => (
              <article className="list-card" key={item.id}>
                <strong>{item.settlement_date}</strong>
                <span>{item.provider_reference}</span>
                <span>
                  Gross {formatIdr(item.gross_amount)} Fee{' '}
                  {formatIdr(item.provider_fee)} Net{' '}
                  {formatIdr(item.net_amount)}
                </span>
              </article>
            ))}
          </div>
        )}
      </section>

      <section
        className="identity-card secondary-panel"
        id="finance-reconciliation"
      >
        <div>
          <h2>Rekonsiliasi Harian</h2>
          <p className="muted">
            Membandingkan kas, QRIS, transfer, dan status pemeriksaan stok.
          </p>
        </div>
        <form className="stack-form" onSubmit={submitReconciliation}>
          <label className="field-label">
            Tanggal bisnis
            <input
              type="date"
              max={localDate()}
              value={recon.date}
              onChange={(event) =>
                setRecon((value) => ({ ...value, date: event.target.value }))
              }
              required
            />
          </label>
          <label className="field-label">
            Kas dihitung (Rp)
            <input
              type="number"
              min="0"
              value={recon.countedCash}
              onChange={(event) =>
                setRecon((value) => ({
                  ...value,
                  countedCash: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Transfer diterima di Bank (Rp)
            <input
              type="number"
              min="0"
              value={recon.bankTransferReceived}
              onChange={(event) =>
                setRecon((value) => ({
                  ...value,
                  bankTransferReceived: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Status stok
            <select
              value={recon.stockStatus}
              onChange={(event) =>
                setRecon((value) => ({
                  ...value,
                  stockStatus: event.target.value as typeof value.stockStatus,
                }))
              }
            >
              <option value="NOT_CHECKED">Belum diperiksa</option>
              <option value="SESUAI">Sesuai</option>
              <option value="PERLU_DIPERIKSA">Perlu diperiksa</option>
            </select>
          </label>
          <button className="primary-button" disabled={!!busy}>
            Simpan Rekonsiliasi Harian
          </button>
        </form>
        <div className="stack-list">
          {(overview?.reconciliations ?? []).map((item) => (
            <article className="list-card" key={item.id}>
              <strong>
                {item.business_date} · {item.result}
              </strong>
              <span>
                Kas {formatIdr(item.expected_cash)} / hitung{' '}
                {formatIdr(item.counted_cash)} selisih{' '}
                {formatIdr(item.cash_variance)}
              </span>
              <span>
                QRIS selisih {formatIdr(item.qris_variance)} Transfer selisih{' '}
                {formatIdr(item.transfer_variance)}
              </span>
            </article>
          ))}
        </div>
      </section>

      <section
        className="identity-card secondary-panel"
        id="finance-receivables"
      >
        <div>
          <h2>Hutang Pelanggan</h2>
          <p className="muted">
            Pembayaran hutang mengurangi piutang; bukan penjualan baru.
          </p>
        </div>
        <div className="stack-list">
          {(overview?.customerDebts ?? []).map((item) => (
            <article className="list-card" key={item.debt_id}>
              <strong>{item.customer_name}</strong>
              <span>Sisa {formatIdr(item.balance)}</span>
              <span className="muted">{item.status}</span>
            </article>
          ))}
          {(overview?.customerDebts ?? []).length === 0 && (
            <p className="muted">Tidak ada Hutang Pelanggan terbuka.</p>
          )}
        </div>
        <form className="stack-form" onSubmit={submitDebtPayment}>
          <label className="field-label">
            Hutang
            <select
              value={debtPayment.debtId}
              onChange={(event) =>
                setDebtPayment((value) => ({
                  ...value,
                  debtId: event.target.value,
                }))
              }
              required
            >
              <option value="">Pilih hutang</option>
              {overview?.customerDebts.map((item) => (
                <option key={item.debt_id} value={item.debt_id}>
                  {item.customer_name} · {formatIdr(item.balance)}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Metode
            <select
              value={debtPayment.method}
              onChange={(event) =>
                setDebtPayment((value) => ({
                  ...value,
                  method: event.target.value as 'CASH' | 'TRANSFER',
                }))
              }
            >
              <option value="CASH">Tunai</option>
              <option value="TRANSFER">Transfer</option>
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={debtPayment.amount}
              onChange={(event) =>
                setDebtPayment((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Catat Pembayaran Hutang
          </button>
        </form>
      </section>

      <section className="identity-card secondary-panel" id="finance-payables">
        <div>
          <h2>Utang Pemasok</h2>
          <p className="muted">
            Pembayaran utang pemasok memindahkan uang dan tidak membuat biaya
            usaha baru.
          </p>
          <Link className="primary-link" to="/pembelian">
            Buka Pembelian
          </Link>
        </div>
        <div className="stack-list">
          {(overview?.supplierPayables ?? []).map((item) => (
            <article className="list-card" key={item.payable_id}>
              <strong>{item.supplier_name}</strong>
              <span>Sisa {formatIdr(item.balance)}</span>
              <span className="muted">
                {item.invoice_reference || 'Tanpa referensi invoice'}
              </span>
            </article>
          ))}
          {(overview?.supplierPayables ?? []).length === 0 && (
            <p className="muted">Tidak ada Utang Pemasok terbuka.</p>
          )}
        </div>
        <form className="stack-form" onSubmit={submitSupplierPayment}>
          <label className="field-label">
            Utang
            <select
              value={supplierPayment.payableId}
              onChange={(event) =>
                setSupplierPayment((value) => ({
                  ...value,
                  payableId: event.target.value,
                }))
              }
              required
            >
              <option value="">Pilih utang pemasok</option>
              {overview?.supplierPayables.map((item) => (
                <option key={item.payable_id} value={item.payable_id}>
                  {item.supplier_name} · {formatIdr(item.balance)}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Metode
            <select
              value={supplierPayment.method}
              onChange={(event) =>
                setSupplierPayment((value) => ({
                  ...value,
                  method: event.target.value as 'CASH' | 'TRANSFER',
                }))
              }
            >
              <option value="CASH">Kas Utama</option>
              <option value="TRANSFER">Bank</option>
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={supplierPayment.amount}
              onChange={(event) =>
                setSupplierPayment((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Bayar Utang Pemasok
          </button>
        </form>
      </section>

      <section className="identity-card secondary-panel" id="finance-kasbon">
        <div>
          <h2>Kasbon Karyawan</h2>
          <p className="muted">
            Terpisah dari Hutang Pelanggan. Foundation ini hanya mencatat
            pencairan Kasbon; mekanisme pembayaran/potongan belum ditetapkan.
          </p>
        </div>
        <div className="stack-list">
          {(overview?.employeeKasbons ?? []).map((item) => (
            <article className="list-card" key={item.kasbon_id}>
              <strong>{item.employee_name}</strong>
              <span>Sisa {formatIdr(item.balance)}</span>
              <span className="muted">{item.status}</span>
            </article>
          ))}
          {(overview?.employeeKasbons ?? []).length === 0 && (
            <p className="muted">Belum ada Kasbon Karyawan.</p>
          )}
        </div>
        <form className="stack-form" onSubmit={submitKasbon}>
          <label className="field-label">
            Karyawan
            <select
              value={kasbon.employeeProfileId}
              onChange={(event) =>
                setKasbon((value) => ({
                  ...value,
                  employeeProfileId: event.target.value,
                }))
              }
              required
            >
              <option value="">Pilih karyawan</option>
              {employeeOptions.map((employee) => (
                <option key={employee.profile_id} value={employee.profile_id}>
                  {employee.display_name} (@{employee.username})
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Sumber dana
            <select
              value={kasbon.sourceMethod}
              onChange={(event) =>
                setKasbon((value) => ({
                  ...value,
                  sourceMethod: event.target.value as 'CASH' | 'TRANSFER',
                }))
              }
            >
              <option value="CASH">Kas Utama</option>
              <option value="TRANSFER">Bank</option>
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={kasbon.amount}
              onChange={(event) =>
                setKasbon((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Catatan
            <input
              value={kasbon.note}
              onChange={(event) =>
                setKasbon((value) => ({
                  ...value,
                  note: event.target.value,
                }))
              }
            />
          </label>
          <button className="primary-button" disabled={!!busy}>
            Catat Kasbon Karyawan
          </button>
        </form>
      </section>

      <section className="identity-card secondary-panel" id="finance-approval">
        <div>
          <h2>Approval Pengeluaran</h2>
          <p className="muted">
            Pengeluaran usaha yang melewati aturan approval diproses di jalur
            terpisah.
          </p>
          <Link className="primary-link" to="/expense-approval">
            Buka Approval Pengeluaran
          </Link>
        </div>
      </section>

      <section className="identity-card secondary-panel" id="finance-personal">
        <div>
          <h2>Pengeluaran Pribadi Owner</h2>
          <p>
            Pengeluaran Pribadi Owner{' '}
            <strong>tidak diperlakukan sebagai biaya usaha</strong> dan{' '}
            <strong>tidak mengurangi laba usaha</strong>. Dana berpindah dari
            Kas Utama/Bank ke akun Pengeluaran Pribadi.
          </p>
        </div>
        <form className="stack-form" onSubmit={submitPersonal}>
          <label className="field-label">
            Sumber
            <select
              value={personal.from}
              onChange={(event) =>
                setPersonal((value) => ({
                  ...value,
                  from: event.target.value,
                }))
              }
              required
            >
              <option value="">Pilih akun</option>
              {ownerCashAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.display_name} · {formatIdr(account.balance)}
                </option>
              ))}
            </select>
          </label>
          <label className="field-label">
            Jumlah (Rp)
            <input
              type="number"
              min="1"
              value={personal.amount}
              onChange={(event) =>
                setPersonal((value) => ({
                  ...value,
                  amount: event.target.value,
                }))
              }
              required
            />
          </label>
          <label className="field-label">
            Keterangan
            <input
              value={personal.reason}
              onChange={(event) =>
                setPersonal((value) => ({
                  ...value,
                  reason: event.target.value,
                }))
              }
              required
            />
          </label>
          <button className="secondary-button" disabled={!!busy}>
            Catat Pengeluaran Pribadi
          </button>
        </form>
      </section>
    </main>
  );
}
