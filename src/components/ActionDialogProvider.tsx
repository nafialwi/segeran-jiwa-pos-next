import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
} from 'react';

type DialogTone = 'default' | 'danger';

type ConfirmActionOptions = {
  title: string;
  description: string;
  confirmLabel?: string;
  cancelLabel?: string;
  tone?: DialogTone;
};

type PromptActionOptions = ConfirmActionOptions & {
  fieldLabel: string;
  initialValue?: string;
  placeholder?: string;
  inputType?: 'text' | 'password' | 'textarea';
  required?: boolean;
  minLength?: number;
  maxLength?: number;
};

type ConfirmRequest = ConfirmActionOptions & {
  kind: 'confirm';
};

type PromptRequest = PromptActionOptions & {
  kind: 'prompt';
};

type ActionRequest = ConfirmRequest | PromptRequest;

type ActionDialogContextValue = {
  confirmAction: (options: ConfirmActionOptions) => Promise<boolean>;
  promptAction: (options: PromptActionOptions) => Promise<string | null>;
};

const ActionDialogContext = createContext<ActionDialogContextValue | null>(
  null,
);

export function useActionDialog() {
  const value = useContext(ActionDialogContext);
  if (!value) {
    throw new Error(
      'useActionDialog must be used inside ActionDialogProvider.',
    );
  }
  return value;
}

export function ActionDialogProvider({ children }: { children: ReactNode }) {
  const [request, setRequest] = useState<ActionRequest | null>(null);
  const [promptValue, setPromptValue] = useState('');
  const resolverRef = useRef<((value: boolean | string | null) => void) | null>(
    null,
  );
  const inputRef = useRef<HTMLInputElement | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);
  const confirmRef = useRef<HTMLButtonElement | null>(null);
  const titleId = useId();
  const descriptionId = useId();

  const settle = useCallback((value: boolean | string | null) => {
    const resolve = resolverRef.current;
    resolverRef.current = null;
    setRequest(null);
    resolve?.(value);
  }, []);

  const confirmAction = useCallback(
    (options: ConfirmActionOptions) =>
      new Promise<boolean>((resolve) => {
        resolverRef.current?.(false);
        resolverRef.current = (value) => resolve(value === true);
        setRequest({ ...options, kind: 'confirm' });
      }),
    [],
  );

  const promptAction = useCallback(
    (options: PromptActionOptions) =>
      new Promise<string | null>((resolve) => {
        resolverRef.current?.(null);
        resolverRef.current = (value) =>
          resolve(typeof value === 'string' ? value : null);
        setPromptValue(options.initialValue ?? '');
        setRequest({ ...options, kind: 'prompt' });
      }),
    [],
  );
  useEffect(() => {
    if (!request) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const frame = window.requestAnimationFrame(() => {
      if (request.kind === 'prompt') {
        if (request.inputType === 'textarea') {
          textareaRef.current?.focus();
        } else {
          inputRef.current?.focus();
          inputRef.current?.select();
        }
      } else {
        confirmRef.current?.focus();
      }
    });

    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      settle(request.kind === 'confirm' ? false : null);
    };
    window.addEventListener('keydown', closeOnEscape);

    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener('keydown', closeOnEscape);
      document.body.style.overflow = previousOverflow;
    };
  }, [request, settle]);

  const contextValue: ActionDialogContextValue = {
    confirmAction,
    promptAction,
  };

  return (
    <ActionDialogContext.Provider value={contextValue}>
      {children}
      {request && (
        <div
          className="action-dialog-backdrop"
          role="presentation"
          onMouseDown={(event) => {
            if (event.currentTarget !== event.target) return;
            settle(request.kind === 'confirm' ? false : null);
          }}
        >
          <section
            className="action-dialog-sheet"
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            aria-describedby={descriptionId}
          >
            <header className="action-dialog-header">
              <div>
                <p className="eyebrow">KONFIRMASI</p>
                <h2 id={titleId}>{request.title}</h2>
              </div>
            </header>

            <p id={descriptionId} className="action-dialog-description">
              {request.description}
            </p>

            <form
              className="action-dialog-form"
              onSubmit={(event) => {
                event.preventDefault();
                if (request.kind === 'confirm') {
                  settle(true);
                  return;
                }
                settle(promptValue);
              }}
            >
              {request.kind === 'prompt' && (
                <label className="action-dialog-field">
                  <span>{request.fieldLabel}</span>
                  {request.inputType === 'textarea' ? (
                    <textarea
                      ref={textareaRef}
                      rows={4}
                      value={promptValue}
                      placeholder={request.placeholder}
                      required={request.required}
                      minLength={request.minLength}
                      maxLength={request.maxLength}
                      onChange={(event) => setPromptValue(event.target.value)}
                    />
                  ) : (
                    <input
                      ref={inputRef}
                      type={request.inputType ?? 'text'}
                      value={promptValue}
                      placeholder={request.placeholder}
                      required={request.required}
                      minLength={request.minLength}
                      maxLength={request.maxLength}
                      autoComplete={
                        request.inputType === 'password'
                          ? 'new-password'
                          : 'off'
                      }
                      onChange={(event) => setPromptValue(event.target.value)}
                    />
                  )}
                </label>
              )}

              <div className="action-dialog-actions">
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() =>
                    settle(request.kind === 'confirm' ? false : null)
                  }
                >
                  {request.cancelLabel ?? 'Batal'}
                </button>
                <button
                  ref={confirmRef}
                  className={
                    request.tone === 'danger'
                      ? 'primary-button action-dialog-danger'
                      : 'primary-button'
                  }
                  type="submit"
                >
                  {request.confirmLabel ?? 'Lanjutkan'}
                </button>
              </div>
            </form>
          </section>
        </div>
      )}
    </ActionDialogContext.Provider>
  );
}
