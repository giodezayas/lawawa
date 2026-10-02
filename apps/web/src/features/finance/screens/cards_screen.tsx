import {
  CardLedger,
  CashMove,
  DomainError,
  formatDateOnly,
  formatMoney,
  shiftCalendarMonth,
  todayIsoDate,
  toMoneyNumber,
  type CardOpening,
  type CashMoveKind,
  type CashMoveProps,
  type TransferCard,
} from '@wawa/domain';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../../../app/providers/auth_provider';
import { useConfirm } from '../../../shared/ui/confirm_dialog';
import { moneyTone } from '../../../shared/ui/money_tone';
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
      <p className={`relative mt-8 text-right text-4xl font-extrabold ${slice.balance < 0 ? 'text-accent' : ''}`}>
        {formatMoney(slice.balance)}
      </p>
      <p className="relative mt-1 text-right text-sm text-white/80">Saldo</p>
      <dl className="relative mt-6 grid grid-cols-2 gap-3 text-xs sm:grid-cols-4">
        <div>
          <dt className="text-white/70">Conteo Inicial</dt>
          <dd className="mt-1 font-semibold">{formatMoney(slice.opening)}</dd>
        </div>
        <div>
          <dt className="text-white/70">Recibido</dt>
          <dd className="mt-1 font-semibold">{formatMoney(slice.received)}</dd>
        </div>
        <div>
          <dt className="text-white/70">Extraído</dt>
          <dd className="mt-1 font-semibold">{formatMoney(slice.withdrawn)}</dd>
        </div>
        <div>
          <dt className="text-white/70">Depositado</dt>
          <dd className="mt-1 font-semibold">{formatMoney(slice.deposited)}</dd>
        </div>
      </dl>
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
  const [opening, setOpening] = useState<CardOpening | null>(null);
  const [openingDate, setOpeningDate] = useState(todayIsoDate());
  const [openingP, setOpeningP] = useState('');
  const [openingF, setOpeningF] = useState('');
  const [savingOpening, setSavingOpening] = useState(false);
  const [moves, setMoves] = useState<CashMoveProps[]>([]);
  const [moveCard, setMoveCard] = useState<TransferCard>('p');
  const [moveKind, setMoveKind] = useState<CashMoveKind>('transfer_to_cash');
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
      const nextOpening = await container.getCardOpening.execute();
      const ledgerTo = nextOpening && nextOpening.asOf > period.to ? nextOpening.asOf : period.to;
      const moveFrom =
        nextOpening && nextOpening.asOf < period.from ? nextOpening.asOf : period.from;
      const [ipvs, nextMoves] = await Promise.all([
        container.listIpvs.execute(),
        container.listCashMoves.execute(moveFrom, ledgerTo),
      ]);
      setOpening(nextOpening);
      if (nextOpening) {
        setOpeningDate(nextOpening.asOf);
        setOpeningP(String(nextOpening.pAmount));
        setOpeningF(String(nextOpening.fAmount));
      }
      setMoves(nextMoves.filter((move) => move.occurredOn >= period.from && move.occurredOn <= period.to));
      setLedger(CardLedger.from(ipvs, nextMoves, period.from, period.to, nextOpening));
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

  async function saveOpening() {
    if (!user) {
      return;
    }
    setSavingOpening(true);
    setPageError('');
    try {
      await container.upsertCardOpening.execute({
        asOf: openingDate,
        pAmount: toMoneyNumber(openingP),
        fAmount: toMoneyNumber(openingF),
        notes: '',
        updatedBy: user.id,
      });
      await load(from, to);
    } catch (error) {
      setPageError(error instanceof DomainError ? error.message : 'No se pudo guardar el saldo inicial.');
    } finally {
      setSavingOpening(false);
    }
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
        kind: moveKind,
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

  const totalBalance = useMemo(() => {
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
          <p className="mt-1 text-sm text-muted">
            No se parte el recaudo viejo. Anota lo que hay hoy en cada tarjeta; desde esa fecha el IPV P/F y las
            extracciones nuevas sí cuentan. Las extracciones de P que ya salieron van incluidas en ese saldo.
          </p>
        </div>
        <Link to="/" className="text-sm font-semibold text-primary">
          Ver Caja
        </Link>
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
          <section className="space-y-4 rounded-3xl border border-line bg-surface p-5">
            <h2 className="text-sm font-semibold text-primary">Saldo Que Hay Ahora</h2>
            <p className="text-sm text-muted">
              {opening
                ? `Conteo desde ${formatDateOnly(opening.asOf)}. Los IPV anteriores no se asignan a P ni a F.`
                : 'Todavía no hay conteo. Escribe lo que queda hoy en P y en F, y la fecha desde la que vas a registrar a qué tarjeta va cada recaudo.'}
            </p>
            <div className="grid gap-3 sm:grid-cols-3">
              <TextField label="Desde *" type="date" value={openingDate} onChange={(event) => setOpeningDate(event.target.value)} />
              <TextField
                label="Tarjeta P *"
                inputMode="decimal"
                value={openingP}
                onChange={(event) => setOpeningP(event.target.value)}
              />
              <TextField
                label="Tarjeta F *"
                inputMode="decimal"
                value={openingF}
                onChange={(event) => setOpeningF(event.target.value)}
              />
            </div>
            <PrimaryButton type="button" loading={savingOpening} onClick={() => void saveOpening()}>
              Guardar Saldo Inicial
            </PrimaryButton>
          </section>
          <div className="grid gap-5 lg:grid-cols-2">
            <BankCard name="Tarjeta P" letter="P" slice={ledger.p} variant="p" />
            <BankCard name="Tarjeta F" letter="F" slice={ledger.f} variant="f" />
          </div>
          <article className="rounded-3xl border border-line bg-white px-5 py-4">
            <p className="text-sm font-medium text-muted">Total En Ambas</p>
            <p className={`mt-1 text-right text-3xl font-extrabold ${moneyTone(totalBalance)}`}>{formatMoney(totalBalance)}</p>
          </article>
          <section className="space-y-4 rounded-3xl border border-line bg-surface p-5">
            <h2 className="text-sm font-semibold text-primary">Registrar Extracción O Depósito</h2>
            <p className="text-sm text-muted">
              Extracción: sale de esa tarjeta y entra a efectivo. Depósito: sale de efectivo y entra a esa tarjeta.
            </p>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
              <TextField label="Fecha *" type="date" value={moveDate} onChange={(event) => setMoveDate(event.target.value)} />
              <label className="grid gap-1 text-sm">
                <span className="font-medium">Tarjeta *</span>
                <select
                  className="h-12 rounded-2xl border border-line bg-white px-3"
                  value={moveCard}
                  onChange={(event) => setMoveCard(event.target.value as TransferCard)}
                >
                  <option value="p">Tarjeta P</option>
                  <option value="f">Tarjeta F</option>
                </select>
              </label>
              <label className="grid gap-1 text-sm">
                <span className="font-medium">Tipo *</span>
                <select
                  className="h-12 rounded-2xl border border-line bg-white px-3"
                  value={moveKind}
                  onChange={(event) => setMoveKind(event.target.value as CashMoveKind)}
                >
                  <option value="transfer_to_cash">Extracción A Efectivo</option>
                  <option value="cash_to_transfer">Depósito Desde Efectivo</option>
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
            <h2 className="text-sm font-semibold text-primary">Movimientos</h2>
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
                          {opening && move.occurredOn < opening.asOf ? ' · No entra en el saldo' : ''}
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
