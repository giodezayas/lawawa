import {
  CardLedger,
  CashMove,
  DomainError,
  formatDateOnly,
  formatMoney,
  shiftCalendarMonth,
  todayIsoDate,
  toMoneyNumber,
  type CashMoveProps,
  type TransferCard,
} from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { PrimaryButton } from '../../../shared/ui/primary_button';
import { TextField } from '../../../shared/ui/text_field';

function BankCard({
  name,
  letter,
  slice,
  variant,
}: {
  name: string;
  letter: string;
  slice: { opening: number; received: number; withdrawn: number; deposited: number; balance: number };
  variant: 'p' | 'f';
}) {
  const face =
    variant === 'p'
      ? 'bg-gradient-to-br from-primary via-primary-dark to-ink text-white'
      : 'bg-gradient-to-br from-ink to-primary text-white';
  return (
    <article className={`relative overflow-hidden rounded-[2rem] p-6 shadow-lg ${face}`}>
      <div className="absolute -right-8 -top-8 h-32 w-32 rounded-full bg-accent/20" />
      <div className="absolute -bottom-10 -left-6 h-28 w-28 rounded-full bg-white/10" />
      <div className="relative flex items-start justify-between">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.28em] text-accent">La Wawa</p>
          <h2 className="mt-2 text-2xl font-extrabold">{name}</h2>
        </div>
        <span className="flex h-12 w-12 items-center justify-center rounded-2xl border border-accent/70 bg-white/10 text-xl font-extrabold text-accent">
          {letter}
        </span>
      </div>
      <p className="relative mt-8 text-right text-4xl font-extrabold">{formatMoney(slice.balance)}</p>
      <p className="relative mt-1 text-right text-sm text-white/80">Queda</p>
    </article>
  );
}

export function CardsScreen() {
  const { container, user } = useAuth();
  const confirm = useConfirm();
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [pageError, setPageError] = useState('');
  const [loading, setLoading] = useState(true);
  const [ledger, setLedger] = useState<ReturnType<typeof CardLedger.from> | null>(null);
  const [moves, setMoves] = useState<CashMoveProps[]>([]);
  const [moveCard, setMoveCard] = useState<TransferCard>('p');
  const [moveDate, setMoveDate] = useState(todayIsoDate());
  const [moveAmount, setMoveAmount] = useState('');
  const [moveNotes, setMoveNotes] = useState('');
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState('');

  async function load(nextFrom?: string, nextTo?: string) {
    setLoading(true);
    try {
      const period = nextFrom && nextTo ? { from: nextFrom, to: nextTo } : await container.getBillingPeriod.execute();
      setFrom(period.from);
      setTo(period.to);
      const [ipvs, nextMoves] = await Promise.all([
        container.listIpvs.execute(),
        container.listCashMoves.execute(period.from, period.to),
      ]);
      setMoves(nextMoves.filter((move) => move.kind === 'transfer_to_cash'));
      setLedger(CardLedger.from(ipvs, nextMoves, period.from, period.to, null));
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudieron cargar las tarjetas.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, [container]);

  function shift(direction: number) {
    if (!from || !to) {
      return;
    }
    const next = shiftCalendarMonth(from, direction);
    void load(next.from, next.to);
  }

  async function saveMove() {
    if (!user) {
      return;
    }
    setSaving(true);
    setPageError('');
    try {
      await container.createCashMove.execute({
        occurredOn: moveDate,
        kind: 'transfer_to_cash',
        card: moveCard,
        amount: toMoneyNumber(moveAmount),
        notes: moveNotes.trim(),
        createdBy: user.id,
      });
      setMoveAmount('');
      setMoveNotes('');
      await load(from, to);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo registrar la extracción.');
    } finally {
      setSaving(false);
    }
  }

  async function deleteMove(id: string) {
    if (!(await confirm({ message: '¿Borrar este movimiento?' }))) {
      return;
    }
    setDeletingId(id);
    setPageError('');
    try {
      await container.deleteCashMove.execute(id);
      await load(from, to);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo borrar el movimiento.');
    } finally {
      setDeletingId('');
    }
  }

  const totalLeft = useMemo(() => {
    if (!ledger) {
      return 0;
    }
    return ledger.p.balance + ledger.f.balance;
  }, [ledger]);

  return (
    <div className="mx-auto max-w-6xl space-y-8">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold">Tarjetas</h1>
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(-1)}>
          Anterior
        </button>
        <p className="text-sm font-semibold">
          {from && to ? `${formatDateOnly(from)} — ${formatDateOnly(to)}` : 'Cargando Período...'}
        </p>
        <button type="button" className="btn-outline h-10 rounded-2xl px-4 text-sm font-semibold" onClick={() => shift(1)}>
          Siguiente
        </button>
      </div>
      {pageError ? <p className="text-sm text-danger">{pageError}</p> : null}
      {loading || !ledger ? (
        pageError ? null : <p className="text-sm text-muted">Cargando Tarjetas...</p>
      ) : (
        <>
          <div className="grid gap-5 lg:grid-cols-2">
            <BankCard name="Cuenta Personal" letter="P" slice={ledger.p} variant="p" />
            <BankCard name="Cuenta Fiscal" letter="F" slice={ledger.f} variant="f" />
          </div>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">Total</p>
            <p className="mt-1 text-right text-3xl font-extrabold">{formatMoney(totalLeft)}</p>
          </article>
          <section className="space-y-4 rounded-3xl border border-line bg-surface p-5">
            <h2 className="text-sm font-semibold text-primary">Registrar Extracción</h2>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <TextField label="Fecha *" type="date" value={moveDate} onChange={(event) => setMoveDate(event.target.value)} />
              <label className="grid gap-1 text-sm">
                <span className="font-medium">Tarjeta *</span>
                <select
                  className="h-12 rounded-2xl border border-line bg-white px-3"
                  value={moveCard}
                  onChange={(event) => setMoveCard(event.target.value as TransferCard)}
                >
                  <option value="p">Cuenta Personal</option>
                  <option value="f">Cuenta Fiscal</option>
                </select>
              </label>
              <TextField
                label="Importe *"
                inputMode="decimal"
                value={moveAmount}
                onChange={(event) => setMoveAmount(event.target.value)}
              />
              <TextField label="Notas" value={moveNotes} onChange={(event) => setMoveNotes(event.target.value)} />
            </div>
            <PrimaryButton type="button" loading={saving} onClick={() => void saveMove()}>
              Registrar
            </PrimaryButton>
          </section>
          <section className="space-y-3">
            <h2 className="text-sm font-semibold text-primary">Extracciones</h2>
            <div className="overflow-x-auto rounded-3xl border border-line bg-white">
              <table className="min-w-full text-sm">
                <thead>
                  <tr className="border-b border-line text-left">
                    <th className="px-4 py-3 font-semibold">Fecha</th>
                    <th className="px-4 py-3 font-semibold">Tarjeta</th>
                    <th className="px-4 py-3 font-semibold">Tipo</th>
                    <th className="px-4 py-3 text-right font-semibold">Importe</th>
                    <th className="px-4 py-3 font-semibold">Notas</th>
                    <th className="px-4 py-3" />
                  </tr>
                </thead>
                <tbody>
                  {moves.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="px-4 py-8 text-center text-muted">
                        Todavía no hay extracciones en este período.
                      </td>
                    </tr>
                  ) : (
                    moves.map((move) => (
                      <tr key={move.id} className="border-t border-line">
                        <td className="px-4 py-3">{formatDateOnly(move.occurredOn)}</td>
                        <td className="px-4 py-3">{CashMove.cardLabel(move.card)}</td>
                        <td className="px-4 py-3">{CashMove.kindLabel(move.kind)}</td>
                        <td className="px-4 py-3 text-right">{formatMoney(move.amount)}</td>
                        <td className="px-4 py-3">
                          {move.notes || '—'}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <button
                            type="button"
                            className="text-danger"
                            disabled={deletingId === move.id}
                            onClick={() => void deleteMove(move.id)}
                          >
                            {deletingId === move.id ? 'Borrando...' : 'Borrar'}
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
