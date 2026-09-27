import type { InputHTMLAttributes } from 'react';

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: string;
};

export function TextField({ label, id, error, required, ...props }: TextFieldProps) {
  return (
    <label className="block" htmlFor={id}>
      <span className="mb-2 block text-sm font-medium text-ink">
        {label}
        {required ? ' *' : ''}
      </span>
      <input
        id={id}
        required={required}
        {...props}
        className="h-12 w-full rounded-2xl border border-line bg-white px-4 text-sm outline-none ring-primary/15 transition focus:border-primary focus:ring-4"
      />
      {error ? <p className="mt-1 text-sm text-danger">{error}</p> : null}
    </label>
  );
}
