import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';

type ConfirmOptions = {
  title?: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
};

type ConfirmFn = (options: ConfirmOptions) => Promise<boolean>;

const ConfirmContext = createContext<ConfirmFn | null>(null);

type Pending = ConfirmOptions & {
  resolve: (value: boolean) => void;
};

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [pending, setPending] = useState<Pending | null>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);

  const confirm = useCallback<ConfirmFn>((options) => {
    return new Promise((resolve) => {
      setPending({ ...options, resolve });
    });
  }, []);

  useEffect(() => {
    if (!pending) {
      return;
    }
    cancelRef.current?.focus();
    const previous = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        pending.resolve(false);
        setPending(null);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = previous;
      window.removeEventListener('keydown', onKey);
    };
  }, [pending]);

  function close(value: boolean) {
    pending?.resolve(value);
    setPending(null);
  }

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      {pending ? (
        <div className="fixed inset-0 z-50 flex items-end justify-center p-4 sm:items-center">
          <button type="button" className="absolute inset-0 bg-ink/40" aria-label="Cerrar" onClick={() => close(false)} />
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="confirm-title"
            aria-describedby="confirm-message"
            className="relative w-full max-w-md rounded-3xl border border-line bg-white p-6 shadow-xl"
          >
            <h2 id="confirm-title" className="text-xl font-extrabold">
              {pending.title ?? 'Confirmar'}
            </h2>
            <p id="confirm-message" className="mt-2 text-sm text-muted">
              {pending.message}
            </p>
            <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <button
                ref={cancelRef}
                type="button"
                className="btn-outline inline-flex h-12 items-center justify-center rounded-2xl px-5 text-sm font-semibold"
                onClick={() => close(false)}
              >
                {pending.cancelLabel ?? 'Cancelar'}
              </button>
              <button
                type="button"
                className="inline-flex h-12 items-center justify-center rounded-2xl border-2 border-danger bg-white px-5 text-sm font-semibold text-danger"
                onClick={() => close(true)}
              >
                {pending.confirmLabel ?? 'Borrar'}
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </ConfirmContext.Provider>
  );
}

export function useConfirm(): ConfirmFn {
  const confirm = useContext(ConfirmContext);
  if (!confirm) {
    throw new Error('useConfirm requiere ConfirmProvider.');
  }
  return confirm;
}
