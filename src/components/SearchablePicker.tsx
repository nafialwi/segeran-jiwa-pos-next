import { useEffect, useMemo, useRef, useState } from 'react';
import { Icon } from '../ui/Icon';

export type SearchablePickerOption = {
  id: string;
  label: string;
  meta?: string;
  keywords?: string;
};

type SearchablePickerProps = {
  label: string;
  value: string;
  options: SearchablePickerOption[];
  eyebrow?: string;
  searchPlaceholder?: string;
  emptyLabel?: string;
  noun?: string;
  onChange: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
};

export function SearchablePicker({
  label,
  value,
  options,
  onChange,
  placeholder = 'Pilih',
  disabled = false,
  eyebrow = 'PILIH DATA',
  searchPlaceholder = 'Ketik untuk mencari…',
  emptyLabel = 'Tidak ada data yang sesuai pencarian.',
  noun = 'data',
}: SearchablePickerProps) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState('');
  const searchRef = useRef<HTMLInputElement>(null);
  const selected = options.find((option) => option.id === value) ?? null;
  const filtered = useMemo(() => {
    const needle = query.trim().toLocaleLowerCase('id');
    if (!needle) return options;

    return options.filter((option) =>
      [option.label, option.meta ?? '', option.keywords ?? '']
        .join(' ')
        .toLocaleLowerCase('id')
        .includes(needle),
    );
  }, [options, query]);

  useEffect(() => {
    if (!open) return;
    const original = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    window.setTimeout(() => searchRef.current?.focus(), 0);

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    window.addEventListener('keydown', closeOnEscape);

    return () => {
      document.body.style.overflow = original;
      window.removeEventListener('keydown', closeOnEscape);
    };
  }, [open]);

  return (
    <div className="searchable-item-field">
      <span className="field-label">{label}</span>
      <button
        className="searchable-item-trigger"
        type="button"
        disabled={disabled}
        aria-haspopup="dialog"
        aria-expanded={open}
        onClick={() => {
          setQuery('');
          setOpen(true);
        }}
      >
        <span className="searchable-item-trigger-copy">
          <strong>{selected?.label ?? placeholder}</strong>
          {selected?.meta && <small>{selected.meta}</small>}
        </span>
        <Icon name="search" size={19} />
      </button>

      {open && (
        <div
          className="searchable-item-backdrop"
          role="presentation"
          onMouseDown={(event) => {
            if (event.currentTarget === event.target) setOpen(false);
          }}
        >
          <section
            className="searchable-item-dialog"
            role="dialog"
            aria-modal="true"
            aria-label={label}
          >
            <header>
              <div>
                <p className="eyebrow">{eyebrow}</p>
                <h2>{label}</h2>
              </div>
              <button
                className="icon-button"
                type="button"
                aria-label="Tutup pemilih barang"
                onClick={() => setOpen(false)}
              >
                <Icon name="close" size={20} />
              </button>
            </header>

            <label className="operations-search-field searchable-item-search">
              <span className="sr-only">Cari barang</span>
              <Icon name="search" size={18} />
              <input
                ref={searchRef}
                type="search"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder={searchPlaceholder}
              />
            </label>
            <div className="searchable-item-results" role="listbox">
              {filtered.length === 0 ? (
                <p className="operations-empty">{emptyLabel}</p>
              ) : (
                filtered.map((option) => {
                  const active = option.id === value;
                  return (
                    <button
                      key={option.id}
                      className={
                        active
                          ? 'searchable-item-option active'
                          : 'searchable-item-option'
                      }
                      type="button"
                      role="option"
                      aria-selected={active}
                      onClick={() => {
                        onChange(option.id);
                        setOpen(false);
                      }}
                    >
                      <span>
                        <strong>{option.label}</strong>
                        {option.meta && <small>{option.meta}</small>}
                      </span>
                      {active ? (
                        <Icon name="check" size={20} />
                      ) : (
                        <Icon name="chevron-right" size={18} />
                      )}
                    </button>
                  );
                })
              )}
            </div>

            <footer>
              <span>
                {filtered.length} {noun}
              </span>
              <button
                className="secondary-button"
                type="button"
                onClick={() => setOpen(false)}
              >
                Batal
              </button>
            </footer>
          </section>
        </div>
      )}
    </div>
  );
}
