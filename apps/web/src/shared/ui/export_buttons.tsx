import { downloadExcelCsv, printPdf } from '../export/table_export';

export function ExportButtons({
  title,
  fileName,
  columns,
  rows,
  disabled = false,
}: {
  title: string;
  fileName: string;
  columns: string[];
  rows: string[][];
  disabled?: boolean;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      <button
        type="button"
        className="btn-outline inline-flex h-10 items-center rounded-2xl px-4 text-sm font-semibold"
        disabled={disabled}
        onClick={() => downloadExcelCsv(fileName, columns, rows)}
      >
        Excel
      </button>
      <button
        type="button"
        className="btn-outline inline-flex h-10 items-center rounded-2xl px-4 text-sm font-semibold"
        disabled={disabled}
        onClick={() => printPdf(title, columns, rows)}
      >
        Pdf
      </button>
    </div>
  );
}
