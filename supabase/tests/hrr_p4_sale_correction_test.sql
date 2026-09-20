begin;

do $$
begin
    if to_regclass('public.sale_corrections') is null then
        raise exception 'HRR_P4_SALE_CORRECTIONS_MISSING';
    end if;
    if to_regprocedure('public.sale_correction_preview(uuid)') is null then
        raise exception 'HRR_P4_PREVIEW_MISSING';
    end if;
    if to_regprocedure('public.correct_sale(uuid,text,text)') is null then
        raise exception 'HRR_P4_COMMAND_MISSING';
    end if;
    if not exists (
        select 1 from pg_trigger
        where tgrelid='public.sale_corrections'::regclass
          and tgname='sale_corrections_immutable'
          and not tgisinternal
    ) then
        raise exception 'HRR_P4_IMMUTABILITY_MISSING';
    end if;
end $$;

rollback;
