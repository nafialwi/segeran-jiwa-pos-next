-- CS-04-SALES FOUNDATION
-- Segeran Jiwa POS Next
-- Sales transaction foundation
-- Immutable business facts


insert into private.schema_versions (
    version,
    milestone,
    blueprint_baseline,
    source_anchor
)
values (
    3,
    'CS-04-SALES',
    '1.0',
    'e6c602fdeab24d70507443274d30ab0bb32bb06c'
);


create table public.sales (
    id uuid primary key default gen_random_uuid(),

    business_id uuid not null
        references public.businesses(id)
        on delete restrict,

    location_id uuid not null
        references public.locations(id)
        on delete restrict,

    shift_id uuid,

    invoice_number text not null,

    cashier_profile_id uuid not null
        references public.profiles(id)
        on delete restrict,

    status text not null,

    subtotal numeric(18,2) not null,

    discount_amount numeric(18,2)
        not null default 0,

    total_amount numeric(18,2) not null,

    note text,

    created_at timestamptz not null default now(),

    constraint sales_invoice_nonempty
        check(length(btrim(invoice_number)) > 0),

    constraint sales_status_valid
        check(
            status in (
                'COMPLETED',
                'VOID',
                'REFUNDED'
            )
        ),

    constraint sales_amount_valid
        check(
            subtotal >= 0
            and discount_amount >= 0
            and total_amount >= 0
        )
);


create table public.sale_items (

    sale_id uuid not null
        references public.sales(id)
        on delete restrict,

    line_no integer not null,

    stock_item_id uuid not null
        references public.stock_items(id)
        on delete restrict,

    quantity numeric(18,3) not null,

    unit_price numeric(18,2) not null,

    subtotal numeric(18,2) not null,


    primary key(
        sale_id,
        line_no
    ),


    constraint sale_items_line_positive
        check(line_no > 0),

    constraint sale_items_quantity_positive
        check(quantity > 0),

    constraint sale_items_price_positive
        check(unit_price >= 0)
);


create table public.payments (

    id uuid primary key default gen_random_uuid(),

    sale_id uuid not null
        references public.sales(id)
        on delete restrict,

    method text not null,

    amount numeric(18,2) not null,

    status text not null default 'PAID',

    verified_by uuid
        references public.profiles(id)
        on delete restrict,

    note text,

    created_at timestamptz not null default now(),


    constraint payments_method_valid
        check(
            method in(
                'CASH',
                'QRIS',
                'TRANSFER',
                'CREDIT'
            )
        ),

    constraint payments_status_valid
        check(
            status in(
                'PENDING',
                'PAID',
                'FAILED'
            )
        ),

    constraint payments_amount_positive
        check(amount > 0)
);


-- Immutable facts

create trigger sales_immutable
before update or delete
on public.sales
for each row
execute function private.prevent_fact_mutation();


create trigger sale_items_immutable
before update or delete
on public.sale_items
for each row
execute function private.prevent_fact_mutation();


create trigger payments_immutable
before update or delete
on public.payments
for each row
execute function private.prevent_fact_mutation();


-- RLS

alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;


revoke all on public.sales from anon, authenticated;
revoke all on public.sale_items from anon, authenticated;
revoke all on public.payments from anon, authenticated;


-- Performance

create index sales_business_created_idx
on public.sales(
    business_id,
    created_at desc
);


create index sales_cashier_idx
on public.sales(
    business_id,
    cashier_profile_id
);


create index payments_sale_idx
on public.payments(
    sale_id
);
