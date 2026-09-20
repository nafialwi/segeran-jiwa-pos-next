-- HRR-P3: Reports & Excel Foundation.
-- Reports are read-only projections over canonical facts. They never create ledger facts.

create or replace function public.report_run(
    p_report_code text,
    p_date_from date default null,
    p_date_to date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_authority jsonb;
    v_business uuid;
    v_actor uuid;
    v_owner boolean;
    v_code text;
    v_from date;
    v_to date;
    v_business_name text;
    v_title text;
    v_summary jsonb := '[]'::jsonb;
    v_sections jsonb := '[]'::jsonb;
    v_warnings jsonb := '[]'::jsonb;
    v_rows jsonb;
    v_rows2 jsonb;
    v_rows3 jsonb;
    v_rows4 jsonb;
    v_rows5 jsonb;
    v_rows6 jsonb;
    v_gross numeric := 0;
    v_refunds numeric := 0;
    v_expenses numeric := 0;
    v_count bigint := 0;
    v_count2 bigint := 0;
    v_qty numeric := 0;
begin
    v_authority := public.get_my_authority();
    v_business := (v_authority ->> 'business_id')::uuid;
    v_actor := (v_authority ->> 'profile_id')::uuid;
    v_owner := coalesce((v_authority ->> 'owner')::boolean, false);
    v_code := upper(btrim(coalesce(p_report_code,'')));
    v_to := coalesce(p_date_to, current_date);
    v_from := coalesce(p_date_from, date_trunc('month', v_to::timestamp)::date);

    if v_business is null or v_actor is null then
        raise exception using errcode='42501', message='REPORT_AUTHORITY_REQUIRED';
    end if;

    if v_from > v_to then
        raise exception using errcode='22023', message='REPORT_DATE_RANGE_INVALID';
    end if;

    if v_code not in ('SALES','PRODUCT','INVENTORY','SHIFT','PURCHASE','FINANCE') then
        raise exception using errcode='22023', message='REPORT_CODE_INVALID';
    end if;

    if v_code in ('SALES','PRODUCT')
       and not (v_owner or private.has_permission(v_business,'REPORT_SALES_LIMITED')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code = 'INVENTORY'
       and not (v_owner or private.has_permission(v_business,'REPORT_INVENTORY')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code = 'PURCHASE'
       and not (v_owner or private.has_permission(v_business,'REPORT_PURCHASE')) then
        raise exception using errcode='42501', message='REPORT_PERMISSION_DENIED';
    elsif v_code in ('SHIFT','FINANCE') and not v_owner then
        raise exception using errcode='42501', message='REPORT_OWNER_REQUIRED';
    end if;

    select b.display_name into v_business_name
    from public.businesses b
    where b.id=v_business;

    if v_code = 'SALES' then
        v_title := 'Laporan Penjualan';

        select coalesce(sum(s.total_amount),0), count(*)
        into v_gross, v_count
        from public.sales s
        left join public.shifts sh on sh.id=s.shift_id
        where s.business_id=v_business
          and s.status <> 'VOID'
          and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to;

        select coalesce(sum(r.sale_total),0), count(*)
        into v_refunds, v_count2
        from public.sale_refunds r
        where r.business_id=v_business
          and r.created_at::date between v_from and v_to;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Transaksi Penjualan','value',v_count,'format','number'),
            jsonb_build_object('label','Penjualan Bruto','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund','value',v_refunds,'format','money'),
            jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds,'format','money')
        );

        select coalesce(jsonb_agg(to_jsonb(x) order by x.event_at desc),'[]'::jsonb)
        into v_rows
        from (
            select
                'PENJUALAN'::text as jenis,
                s.invoice_number as nomor_transaksi,
                coalesce(sh.opened_at::date,s.created_at::date)::text as tanggal,
                s.created_at as event_at,
                cashier.display_name as pengguna,
                loc.display_name as lokasi,
                coalesce((select string_agg(p.method, ', ' order by p.created_at)
                          from public.payments p where p.sale_id=s.id),'—') as metode,
                s.total_amount as nominal,
                case when r.id is null then s.status else 'REFUNDED' end as status
            from public.sales s
            join public.profiles cashier on cashier.id=s.cashier_profile_id
            join public.locations loc on loc.id=s.location_id
            left join public.shifts sh on sh.id=s.shift_id
            left join public.sale_refunds r on r.sale_id=s.id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            union all
            select
                'REFUND'::text,
                s.invoice_number,
                r.created_at::date::text,
                r.created_at,
                actor.display_name,
                loc.display_name,
                r.refund_method,
                r.sale_total * -1,
                'REFUNDED'
            from public.sale_refunds r
            join public.sales s on s.id=r.sale_id
            join public.profiles actor on actor.id=r.actor_profile_id
            join public.locations loc on loc.id=s.location_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
        ) x;

        with sold as (
            select
                li.stock_item_id,
                sum(li.quantity) sold_qty,
                sum(li.subtotal) gross_item_value
            from public.sale_items li
            join public.sales s on s.id=li.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by li.stock_item_id
        ), refunded as (
            select
                li.stock_item_id,
                sum(li.quantity) refunded_qty,
                sum(li.subtotal) refunded_item_value
            from public.sale_refunds r
            join public.sale_items li on li.sale_id=r.sale_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by li.stock_item_id
        )
        select coalesce(jsonb_agg(jsonb_build_object(
            'kode',si.code,
            'produk',si.display_name,
            'qty_terjual',coalesce(sold.sold_qty,0),
            'qty_refund',coalesce(refunded.refunded_qty,0),
            'qty_bersih',coalesce(sold.sold_qty,0)-coalesce(refunded.refunded_qty,0),
            'nilai_bruto_item',coalesce(sold.gross_item_value,0),
            'nilai_refund_item',coalesce(refunded.refunded_item_value,0),
            'nilai_bersih_item',coalesce(sold.gross_item_value,0)-coalesce(refunded.refunded_item_value,0)
        ) order by (coalesce(sold.gross_item_value,0)-coalesce(refunded.refunded_item_value,0)) desc),'[]'::jsonb)
        into v_rows2
        from public.stock_items si
        left join sold on sold.stock_item_id=si.id
        left join refunded on refunded.stock_item_id=si.id
        where si.business_id=v_business
          and (sold.stock_item_id is not null or refunded.stock_item_id is not null);

        with paid as (
            select p.method, sum(p.amount) sales_amount
            from public.payments p
            join public.sales s on s.id=p.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and p.status='PAID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by p.method
        ), returned as (
            select r.refund_method as method,
                   sum(r.payout_amount) refund_payout,
                   sum(r.receivable_cancelled_amount) receivable_cancelled
            from public.sale_refunds r
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by r.refund_method
        ), methods as (
            select method from paid
            union
            select method from returned
        )
        select coalesce(jsonb_agg(jsonb_build_object(
            'metode',m.method,
            'penerimaan_penjualan',coalesce(p.sales_amount,0),
            'pengembalian_dana',coalesce(r.refund_payout,0),
            'piutang_dibatalkan',coalesce(r.receivable_cancelled,0)
        ) order by m.method),'[]'::jsonb)
        into v_rows3
        from methods m
        left join paid p on p.method=m.method
        left join returned r on r.method=m.method;

        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','transactions','title','Transaksi',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','nomor_transaksi','label','Nomor Transaksi','type','text','width',22),
                    jsonb_build_object('key','tanggal','label','Tanggal','type','date','width',14),
                    jsonb_build_object('key','pengguna','label','Pengguna','type','text','width',20),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','metode','label','Metode','type','text','width',16),
                    jsonb_build_object('key','nominal','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),
                'rows',v_rows,
                'totals',jsonb_build_array(
                    jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds,'format','money')
                )
            ),
            jsonb_build_object(
                'key','products','title','Produk',
                'note','Nilai item adalah nilai bruto baris sebelum diskon tingkat transaksi.',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','qty_terjual','label','Qty Terjual','type','number','width',14),
                    jsonb_build_object('key','qty_refund','label','Qty Refund','type','number','width',14),
                    jsonb_build_object('key','qty_bersih','label','Qty Bersih','type','number','width',14),
                    jsonb_build_object('key','nilai_bruto_item','label','Nilai Bruto Item','type','money','width',18),
                    jsonb_build_object('key','nilai_refund_item','label','Nilai Refund Item','type','money','width',18),
                    jsonb_build_object('key','nilai_bersih_item','label','Nilai Bersih Item','type','money','width',18)
                ),
                'rows',v_rows2
            ),
            jsonb_build_object(
                'key','payments','title','Metode Pembayaran',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','metode','label','Metode','type','text','width',18),
                    jsonb_build_object('key','penerimaan_penjualan','label','Penerimaan Penjualan','type','money','width',22),
                    jsonb_build_object('key','pengembalian_dana','label','Pengembalian Dana','type','money','width',20),
                    jsonb_build_object('key','piutang_dibatalkan','label','Piutang Dibatalkan','type','money','width',20)
                ),
                'rows',v_rows3
            )
        );

    elsif v_code = 'PRODUCT' then
        v_title := 'Laporan Produk';

        with sold as (
            select li.stock_item_id,sum(li.quantity) sold_qty,sum(li.subtotal) gross_value
            from public.sale_items li
            join public.sales s on s.id=li.sale_id
            left join public.shifts sh on sh.id=s.shift_id
            where s.business_id=v_business
              and s.status <> 'VOID'
              and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to
            group by li.stock_item_id
        ), refunded as (
            select li.stock_item_id,sum(li.quantity) refunded_qty,sum(li.subtotal) refunded_value
            from public.sale_refunds r
            join public.sale_items li on li.sale_id=r.sale_id
            where r.business_id=v_business
              and r.created_at::date between v_from and v_to
            group by li.stock_item_id
        )
        select
            coalesce(jsonb_agg(jsonb_build_object(
                'kode',si.code,'produk',si.display_name,'kategori',si.sale_category,
                'harga_jual',si.sale_price,
                'qty_terjual',coalesce(s.sold_qty,0),
                'qty_refund',coalesce(r.refunded_qty,0),
                'qty_bersih',coalesce(s.sold_qty,0)-coalesce(r.refunded_qty,0),
                'nilai_bruto_item',coalesce(s.gross_value,0),
                'nilai_refund_item',coalesce(r.refunded_value,0),
                'nilai_bersih_item',coalesce(s.gross_value,0)-coalesce(r.refunded_value,0)
            ) order by (coalesce(s.sold_qty,0)-coalesce(r.refunded_qty,0)) desc,si.display_name),'[]'::jsonb),
            count(*) filter (where s.stock_item_id is not null or r.stock_item_id is not null),
            coalesce(sum(coalesce(s.sold_qty,0)),0),
            coalesce(sum(coalesce(r.refunded_qty,0)),0)
        into v_rows,v_count,v_qty,v_refunds
        from public.stock_items si
        left join sold s on s.stock_item_id=si.id
        left join refunded r on r.stock_item_id=si.id
        where si.business_id=v_business
          and (s.stock_item_id is not null or r.stock_item_id is not null);

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Produk Terjual','value',v_count,'format','number'),
            jsonb_build_object('label','Qty Terjual','value',v_qty,'format','number'),
            jsonb_build_object('label','Qty Refund','value',v_refunds,'format','number'),
            jsonb_build_object('label','Qty Bersih','value',v_qty-v_refunds,'format','number')
        );
        v_sections := jsonb_build_array(jsonb_build_object(
            'key','products','title','Kinerja Produk',
            'note','Nilai item adalah nilai bruto baris sebelum diskon tingkat transaksi.',
            'columns',jsonb_build_array(
                jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                jsonb_build_object('key','kategori','label','Kategori','type','text','width',18),
                jsonb_build_object('key','harga_jual','label','Harga Jual','type','money','width',16),
                jsonb_build_object('key','qty_terjual','label','Qty Terjual','type','number','width',14),
                jsonb_build_object('key','qty_refund','label','Qty Refund','type','number','width',14),
                jsonb_build_object('key','qty_bersih','label','Qty Bersih','type','number','width',14),
                jsonb_build_object('key','nilai_bersih_item','label','Nilai Bersih Item','type','money','width',20)
            ),
            'rows',v_rows
        ));

    elsif v_code = 'INVENTORY' then
        v_title := 'Laporan Persediaan';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.lokasi,x.produk),'[]'::jsonb),
               count(*),
               count(*) filter (where x.quantity > 0)
        into v_rows,v_count,v_count2
        from (
            select
                l.display_name as lokasi,
                si.code as kode,
                si.display_name as produk,
                si.item_kind as jenis,
                si.base_unit as satuan,
                coalesce(ib.quantity,0) as quantity,
                si.inventory_tracked
            from public.locations l
            cross join public.stock_items si
            left join public.inventory_balances ib
              on ib.business_id=v_business
             and ib.location_id=l.id
             and ib.stock_item_id=si.id
            where l.business_id=v_business and l.active
              and si.business_id=v_business and si.active
              and si.inventory_tracked
              and (v_owner or private.has_inventory_location_scope(v_business,v_actor,l.id))
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.tanggal desc,x.lokasi,x.produk),'[]'::jsonb)
        into v_rows2
        from (
            select
                im.created_at::date::text as tanggal,
                l.display_name as lokasi,
                si.code as kode,
                si.display_name as produk,
                im.movement_type as jenis,
                im.reason_code as alasan,
                sum(line.quantity_delta) as perubahan
            from public.inventory_movements im
            join public.inventory_movement_lines line on line.movement_id=im.id
            join public.locations l on l.id=line.location_id
            join public.stock_items si on si.id=line.stock_item_id
            where im.business_id=v_business
              and im.created_at::date between v_from and v_to
              and (v_owner or private.has_inventory_location_scope(v_business,v_actor,l.id))
            group by im.created_at::date,l.display_name,si.code,si.display_name,im.movement_type,im.reason_code
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Baris Saldo Stok','value',v_count,'format','number'),
            jsonb_build_object('label','Baris Stok Positif','value',v_count2,'format','number'),
            jsonb_build_object('label','Snapshot','value',current_date::text,'format','date')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','balances','title','Saldo Persediaan Saat Ini',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','satuan','label','Satuan','type','text','width',12),
                    jsonb_build_object('key','quantity','label','Jumlah','type','number','width',14)
                ),
                'rows',v_rows
            ),
            jsonb_build_object(
                'key','movements','title','Pergerakan Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','tanggal','label','Tanggal','type','date','width',14),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','kode','label','Kode','type','text','width',22),
                    jsonb_build_object('key','produk','label','Produk','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','alasan','label','Alasan','type','text','width',24),
                    jsonb_build_object('key','perubahan','label','Perubahan','type','number','width',14)
                ),
                'rows',v_rows2
            )
        );

    elsif v_code = 'SHIFT' then
        v_title := 'Laporan Shift';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.opened_at desc),'[]'::jsonb),
               count(*),
               coalesce(sum(x.sale_total),0),
               coalesce(sum(x.refund_total),0)
        into v_rows,v_count,v_gross,v_refunds
        from (
            select
                s.id as shift_id,
                s.opened_at,
                s.closed_at,
                s.status,
                p.display_name as kasir,
                l.display_name as lokasi,
                s.opening_balance,
                coalesce(a.sale_total,0) sale_total,
                coalesce(a.refund_total,0) refund_total,
                coalesce(a.cash_in_total,0) cash_in_total,
                coalesce(a.cash_out_total,0) cash_out_total,
                private.cs05_shift_expected_cash(s.id) as expected_cash,
                s.actual_cash,
                s.variance
            from public.shifts s
            join public.profiles p on p.id=s.cashier_profile_id
            join public.locations l on l.id=s.location_id
            left join lateral (
                select
                    sum(ct.amount) filter (where ct.transaction_type='SALE') sale_total,
                    sum(ct.amount) filter (where ct.transaction_type='REFUND') refund_total,
                    sum(ct.amount) filter (where ct.transaction_type='CASH_IN') cash_in_total,
                    sum(ct.amount) filter (where ct.transaction_type='CASH_OUT') cash_out_total
                from public.cash_transactions ct
                where ct.shift_id=s.id
            ) a on true
            where s.business_id=v_business
              and s.opened_at::date between v_from and v_to
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Jumlah Shift','value',v_count,'format','number'),
            jsonb_build_object('label','Penjualan Tunai','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund Tunai','value',v_refunds,'format','money')
        );
        v_sections := jsonb_build_array(jsonb_build_object(
            'key','shifts','title','Shift',
            'columns',jsonb_build_array(
                jsonb_build_object('key','opened_at','label','Buka','type','datetime','width',22),
                jsonb_build_object('key','closed_at','label','Tutup','type','datetime','width',22),
                jsonb_build_object('key','kasir','label','Kasir','type','text','width',20),
                jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                jsonb_build_object('key','status','label','Status','type','text','width',12),
                jsonb_build_object('key','opening_balance','label','Kas Awal','type','money','width',16),
                jsonb_build_object('key','sale_total','label','Penjualan Tunai','type','money','width',18),
                jsonb_build_object('key','refund_total','label','Refund Tunai','type','money','width',18),
                jsonb_build_object('key','cash_in_total','label','Kas Masuk','type','money','width',16),
                jsonb_build_object('key','cash_out_total','label','Kas Keluar','type','money','width',16),
                jsonb_build_object('key','expected_cash','label','Expected Closing','type','money','width',18),
                jsonb_build_object('key','actual_cash','label','Kas Aktual','type','money','width',16),
                jsonb_build_object('key','variance','label','Selisih','type','money','width',16)
            ),
            'rows',v_rows
        ));

    elsif v_code = 'PURCHASE' then
        v_title := 'Laporan Pembelian';

        select coalesce(jsonb_agg(to_jsonb(x) order by x.ordered_at desc),'[]'::jsonb),
               count(*),
               coalesce(sum(x.total),0)
        into v_rows,v_count,v_gross
        from (
            select
                po.order_number,
                po.ordered_at,
                po.status,
                sup.display_name as pemasok,
                loc.display_name as lokasi,
                coalesce(sum(pol.line_total),0) as total
            from public.purchase_orders po
            join public.suppliers sup on sup.id=po.supplier_id
            join public.locations loc on loc.id=po.location_id
            left join public.purchase_order_lines pol on pol.purchase_order_id=po.id
            where po.business_id=v_business
              and po.ordered_at::date between v_from and v_to
            group by po.id,po.order_number,po.ordered_at,po.status,sup.display_name,loc.display_name
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.received_at desc),'[]'::jsonb)
        into v_rows2
        from (
            select
                gr.receipt_number,
                gr.received_at,
                gr.posted_at,
                gr.status,
                po.order_number,
                sup.display_name as pemasok,
                loc.display_name as lokasi,
                coalesce(sum(grl.base_quantity),0) as jumlah_dasar
            from public.goods_receipts gr
            left join public.purchase_orders po on po.id=gr.purchase_order_id
            left join public.suppliers sup on sup.id=po.supplier_id
            join public.locations loc on loc.id=gr.location_id
            left join public.goods_receipt_lines grl on grl.goods_receipt_id=gr.id
            where gr.business_id=v_business
              and gr.received_at::date between v_from and v_to
            group by gr.id,gr.receipt_number,gr.received_at,gr.posted_at,gr.status,
                     po.order_number,sup.display_name,loc.display_name
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows3
        from (
            select
                spb.supplier_name as pemasok,
                spb.invoice_reference as referensi,
                spb.original_amount,
                spb.paid_amount,
                spb.balance,
                spb.status,
                spb.created_at
            from public.supplier_payable_balances spb
            where spb.business_id=v_business
              and spb.created_at::date between v_from and v_to
        ) x;

        v_summary := jsonb_build_array(
            jsonb_build_object('label','Pesanan Pembelian','value',v_count,'format','number'),
            jsonb_build_object('label','Nilai Pesanan','value',v_gross,'format','money'),
            jsonb_build_object('label','Periode','value',v_from::text || ' s.d. ' || v_to::text,'format','text')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','orders','title','Pesanan Pembelian',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','order_number','label','Nomor','type','text','width',22),
                    jsonb_build_object('key','ordered_at','label','Tanggal','type','datetime','width',22),
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','total','label','Total','type','money','width',18)
                ),
                'rows',v_rows
            ),
            jsonb_build_object(
                'key','receipts','title','Barang Diterima',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','receipt_number','label','Nomor Terima','type','text','width',22),
                    jsonb_build_object('key','received_at','label','Diterima','type','datetime','width',22),
                    jsonb_build_object('key','order_number','label','Nomor Pesanan','type','text','width',22),
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','lokasi','label','Lokasi','type','text','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','jumlah_dasar','label','Jumlah Dasar','type','number','width',16)
                ),
                'rows',v_rows2
            ),
            jsonb_build_object(
                'key','payables','title','Utang Pemasok dari Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',22),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),
                'rows',v_rows3
            )
        );

    else
        v_title := 'Laporan Keuangan';

        select coalesce(sum(s.total_amount),0)
        into v_gross
        from public.sales s
        left join public.shifts sh on sh.id=s.shift_id
        where s.business_id=v_business
          and s.status <> 'VOID'
          and coalesce(sh.opened_at::date,s.created_at::date) between v_from and v_to;

        select coalesce(sum(r.sale_total),0)
        into v_refunds
        from public.sale_refunds r
        where r.business_id=v_business
          and r.created_at::date between v_from and v_to;

        select coalesce(sum(e.amount),0)
        into v_expenses
        from public.business_expenses e
        where e.business_id=v_business
          and e.approval_state='POSTED'
          and e.created_at::date between v_from and v_to;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.akun),'[]'::jsonb)
        into v_rows
        from (
            select ma.code,ma.display_name as akun,ma.account_type as jenis,
                   coalesce(mb.balance,0) as saldo
            from public.money_accounts ma
            left join public.money_balances mb
              on mb.business_id=ma.business_id and mb.account_id=ma.id
            where ma.business_id=v_business and ma.active
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows2
        from (
            select
                mm.created_at,
                mm.movement_type as jenis,
                fa.display_name as dari_akun,
                ta.display_name as ke_akun,
                mm.amount,
                mm.source_type as sumber,
                mm.source_ref as referensi,
                mm.reason_code as alasan
            from public.money_movements mm
            left join public.money_accounts fa on fa.id=mm.from_account_id
            left join public.money_accounts ta on ta.id=mm.to_account_id
            where mm.business_id=v_business
              and mm.created_at::date between v_from and v_to
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows3
        from (
            select e.created_at,e.category_code as kategori,e.description,
                   e.amount,ma.display_name as sumber_dana
            from public.business_expenses e
            join public.money_accounts ma on ma.id=e.funding_account_id
            where e.business_id=v_business
              and e.approval_state='POSTED'
              and e.created_at::date between v_from and v_to
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows4
        from (
            select customer_name as pelanggan,original_amount,paid_amount,balance,status,created_at
            from public.customer_debt_balances
            where business_id=v_business and balance > 0
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows5
        from (
            select supplier_name as pemasok,invoice_reference as referensi,
                   original_amount,paid_amount,balance,status,created_at
            from public.supplier_payable_balances
            where business_id=v_business and balance > 0
        ) x;

        select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc),'[]'::jsonb)
        into v_rows6
        from (
            select employee_name as karyawan,original_amount,paid_amount,balance,status,note,created_at
            from public.employee_kasbon_balances
            where business_id=v_business and balance > 0
        ) x;

        select count(*) into v_count
        from public.stock_items si
        where si.business_id=v_business and si.sale_enabled and si.active;

        v_warnings := jsonb_build_array(
            'Coverage HPP belum tersedia dari authority data saat ini. Sistem tidak menampilkan Laba Bersih sebagai angka pasti.'
        );
        v_summary := jsonb_build_array(
            jsonb_build_object('label','Penjualan Bruto','value',v_gross,'format','money'),
            jsonb_build_object('label','Refund','value',v_refunds,'format','money'),
            jsonb_build_object('label','Penjualan Bersih','value',v_gross-v_refunds,'format','money'),
            jsonb_build_object('label','Pengeluaran Usaha','value',v_expenses,'format','money'),
            jsonb_build_object('label','Coverage HPP','value','0 / ' || v_count::text || ' produk aktif','format','text'),
            jsonb_build_object('label','Estimasi Laba','value',null,'format','money')
        );
        v_sections := jsonb_build_array(
            jsonb_build_object(
                'key','accounts','title','Ringkasan Saldo Akun',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','code','label','Kode','type','text','width',22),
                    jsonb_build_object('key','akun','label','Akun','type','text','width',28),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','saldo','label','Saldo','type','money','width',18)
                ),'rows',v_rows
            ),
            jsonb_build_object(
                'key','money','title','Arus Uang Periode',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','created_at','label','Waktu','type','datetime','width',22),
                    jsonb_build_object('key','jenis','label','Jenis','type','text','width',16),
                    jsonb_build_object('key','dari_akun','label','Dari Akun','type','text','width',24),
                    jsonb_build_object('key','ke_akun','label','Ke Akun','type','text','width',24),
                    jsonb_build_object('key','amount','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','sumber','label','Sumber','type','text','width',20),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',24),
                    jsonb_build_object('key','alasan','label','Alasan','type','text','width',24)
                ),'rows',v_rows2
            ),
            jsonb_build_object(
                'key','expenses','title','Pengeluaran Usaha',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','created_at','label','Waktu','type','datetime','width',22),
                    jsonb_build_object('key','kategori','label','Kategori','type','text','width',20),
                    jsonb_build_object('key','description','label','Keterangan','type','text','width',32),
                    jsonb_build_object('key','amount','label','Nominal','type','money','width',18),
                    jsonb_build_object('key','sumber_dana','label','Sumber Dana','type','text','width',24)
                ),'rows',v_rows3
            ),
            jsonb_build_object(
                'key','customer_debts','title','Hutang Pelanggan',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pelanggan','label','Pelanggan','type','text','width',24),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),'rows',v_rows4
            ),
            jsonb_build_object(
                'key','supplier_payables','title','Utang Pemasok',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','pemasok','label','Pemasok','type','text','width',24),
                    jsonb_build_object('key','referensi','label','Referensi','type','text','width',22),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14)
                ),'rows',v_rows5
            ),
            jsonb_build_object(
                'key','kasbon','title','Kasbon Karyawan',
                'columns',jsonb_build_array(
                    jsonb_build_object('key','karyawan','label','Karyawan','type','text','width',24),
                    jsonb_build_object('key','original_amount','label','Nilai Awal','type','money','width',18),
                    jsonb_build_object('key','paid_amount','label','Dibayar','type','money','width',18),
                    jsonb_build_object('key','balance','label','Sisa','type','money','width',18),
                    jsonb_build_object('key','status','label','Status','type','text','width',14),
                    jsonb_build_object('key','note','label','Catatan','type','text','width',30)
                ),'rows',v_rows6
            )
        );
    end if;

    return jsonb_build_object(
        'report_code',v_code,
        'report_title',v_title,
        'business_name',v_business_name,
        'period',jsonb_build_object('date_from',v_from,'date_to',v_to),
        'generated_at',now(),
        'summary',v_summary,
        'warnings',v_warnings,
        'sections',v_sections
    );
end;
$$;

revoke execute on function public.report_run(text,date,date)
from public, anon, authenticated, service_role;
grant execute on function public.report_run(text,date,date)
to authenticated;
