export type CardOpeningProps = {
  readonly asOf: string;
  readonly pAmount: number;
  readonly fAmount: number;
  readonly cashAsOf: string;
  readonly cashAmount: number;
  readonly notes: string;
};

export type CardOpening = Readonly<CardOpeningProps>;

export const CardOpening = {
  create(props: CardOpeningProps): CardOpening {
    return Object.freeze({ ...props });
  },
};
