type OperationalStateProps = {
  kind: 'loading' | 'empty' | 'error';
  title?: string;
  message: string;
  skeletonItems?: number;
};

export function OperationalState({
  kind,
  title,
  message,
  skeletonItems = 3,
}: OperationalStateProps) {
  if (kind === 'loading') {
    return (
      <section
        className="operational-state operational-state-loading"
        role="status"
        aria-live="polite"
        aria-label={message}
      >
        <div className="operations-card-skeleton" aria-hidden="true">
          {Array.from({ length: skeletonItems }, (_, index) => (
            <span key={index} />
          ))}
        </div>
        <span className="sr-only">{message}</span>
      </section>
    );
  }

  if (kind === 'error') {
    return (
      <section
        className="error-banner operational-state operational-state-error"
        role="alert"
      >
        {title && <strong>{title}</strong>}
        <span>{message}</span>
      </section>
    );
  }

  return (
    <section className="empty-state operational-state operational-state-empty">
      {title && <strong>{title}</strong>}
      <p>{message}</p>
    </section>
  );
}
