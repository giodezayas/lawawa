import { DomainError, expenseCadences, ExpenseEntry, todayIsoDate, toMoneyNumber, type ExpenseCadence } from '@wawa/domain';
import { useEffect, useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

export function ExpenseEditorScreen() {
  const { expenseId } = useParams();
  const isCreate = expenseId === undefined;
  const navigate = useNavigate();
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [name, setName] = useState('');
  const [occurredOn, setOccurredOn] = useState(todayIsoDate());
  const [cadence, setCadence] = useState<ExpenseCadence>('once');
  const [amount, setAmount] = useState('');
  const [notes, setNotes] = useState('');
  const [pageError, setPageError] = useState('');
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [ready, setReady] = useState(isCreate);

  useEffect(() => {
    if (!expenseId) {
      return;
    }
    void container.getExpenseEntry
      .execute(expenseId)
      .then((entry) => {
        setName(entry.name);
        setOccurredOn(entry.occurredOn);
        setCadence(entry.cadence);
        setAmount(String(entry.amount));
        setNotes(entry.notes);
        setReady(true);
      })
      .catch((error) => {
        setPageError(error instanceof DomainError ? error.message : 'No se pudo abrir el gasto.');
      });
  }, [container, expenseId]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!user) {
      return;
    }
    setPageError('');
    setSaving(true);
    try {
      const payload = {
        name,
        occurredOn,
        cadence,
        amount: toMoneyNumber(amount),
        notes: notes.trim(),
      };
      if (expenseId) {
        await container.updateExpenseEntry.execute({ id: expenseId, ...payload });
      } else {
        await container.createExpenseEntry.execute({ ...payload, createdBy: user.id });
      }
      navigate('/finanzas/gastos');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el gasto.');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!expenseId || !(await confirm({ message: '¿Borrar este gasto?' }))) {
      return;
    }
    setDeleting(true);
    try {
      await container.deleteExpenseEntry.execute(expenseId);
      navigate('/finanzas/gastos');
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el gasto.');
    } finally {
      setDeleting(false);
    }
  }

  if (!ready) {
    return pageError ? <p className="text-sm text-danger">{pageError}</p> : <p className="text-sm text-muted">Cargando Gasto...</p>;
  }

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div className="flex items-end justify-between gap-4">
        <h1 className="text-2xl font-extrabold">{isCreate ? 'Registrar Gasto' : 'Editar Gasto'}</h1>
        <Link to="/finanzas/gastos" className="text-sm font-semibold text-primary">
          Volver A Gastos
        </Link>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      <form onSubmit={(event) => void handleSubmit(event)} className="space-y-4 rounded-3xl border border-line bg-surface p-5">
        <TextField id="expense-name" label="Concepto" required value={name} onChange={(event) => setName(event.target.value)} />
        <TextField
          id="occurred-on"
          label={cadence === 'once' ? 'Fecha' : 'Desde'}
          type="date"
          required
          value={occurredOn}
          onChange={(event) => setOccurredOn(event.target.value)}
        />
        <label className="block" htmlFor="cadence">
          <span className="mb-2 block text-sm font-medium text-ink">Frecuencia *</span>
          <select
            id="cadence"
            required
            value={cadence}
            onChange={(event) => setCadence(event.target.value as ExpenseCadence)}
            className="h-12 w-full rounded-2xl border border-line bg-white px-4 text-sm outline-none ring-primary/15 transition focus:border-primary focus:ring-4"
          >
            {expenseCadences.map((item) => (
              <option key={item} value={item}>
                {ExpenseEntry.cadenceLabel(item)}
              </option>
            ))}
          </select>
        </label>
        <TextField
          id="amount"
          label="Importe"
          inputMode="decimal"
          required
          value={amount}
          onChange={(event) => setAmount(event.target.value)}
        />
        <TextField id="notes" label="Notas" value={notes} onChange={(event) => setNotes(event.target.value)} />
        <PrimaryButton type="submit" loading={saving} className="w-full">
          {isCreate ? 'Guardar Gasto' : 'Guardar Cambios'}
        </PrimaryButton>
      </form>
      {isCreate ? null : (
        <button type="button" className="text-sm text-danger" disabled={deleting} onClick={() => void handleDelete()}>
          {deleting ? 'Borrando...' : 'Borrar Gasto'}
        </button>
      )}
    </div>
  );
}
