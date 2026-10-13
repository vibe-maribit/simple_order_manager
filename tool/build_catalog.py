#!/usr/bin/env python3
"""Genera `assets/catalog/catalogo.json` dal nuovo listino.

Legge il file XLS binario `LISTINO.APP.xls` (foglio `Foglio 1`, formato BIFF8)
tramite `xlrd` (dipendenza: `pip install xlrd==2.0.1`) e produce un array JSON
compatto con un oggetto per riga (la prima riga è l'intestazione):

    {
      "id": "cat-<n>",
      "name": "Descrizione (colonna A)",
      "unitOfMeasure": "Unità di misura (colonna B)",
      "currency": "Divisa fissa `E`",
      "unitPrice": Prezzo (colonna C, numerico),
      "discount": "Sconti (colonna D)",
      "taxRate": IVA (colonna E, vuota -> 22.0)
    }

Nota: il file sorgente è .xls binario legacy e non leggibile con standard
library; serve `xlrd==2.0.1`. Il JSON generato è committato nel repository
(gli id `cat-<n>` sono stabili in base all'ordine di lettura).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    import xlrd  # type: ignore
except ImportError:
    xlrd = None

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = ROOT / "tool" / "catalogo" / "LISTINO APP.xls"
DEFAULT_OUTPUT = ROOT / "assets" / "catalog" / "catalogo.json"


def _to_number(val, fallback: float = 0.0) -> float:
    """Converte valore (xlrd) a float arrotondato a 2 decimali."""
    if val is None or (isinstance(val, str) and val.strip() == ""):
        return fallback
    try:
        if isinstance(val, (int, float)) and not isinstance(val, bool):
            return round(float(val), 2)
        # Gestisce eventuali formati stringa
        s = str(val).strip()
        if not s:
            return fallback
        # Sostituisce virgola con punto per compatibilità
        s = s.replace(",", ".")
        return round(float(s), 2)
    except Exception:
        return fallback


def _to_str(val) -> str:
    if val is None:
        return ""
    return str(val).strip()


def build(input_path: Path = DEFAULT_INPUT, output_path: Path = DEFAULT_OUTPUT) -> list[dict]:
    if xlrd is None:
        raise RuntimeError("xlrd==2.0.1 non installato. Eseguire: pip install xlrd==2.0.1")

    rows: list[dict] = []
    with xlrd.open_workbook(str(input_path), formatting_info=False) as wb:
        # Usa "Foglio 1" se presente
        try:
            sheet = wb.sheet_by_name("Foglio 1")
        except xlrd.biffh.XLRDError:
            sheet = wb.sheet_by_index(0)

        for r in range(sheet.nrows):
            # Riga 0 = intestazione
            if r == 0:
                continue
            # Colonne: A=0 Descrizione, B=1 UM, C=2 Prezzo, D=3 Sconti, E=4 IVA
            try:
                name = _to_str(sheet.cell_value(r, 0))
            except IndexError:
                continue
            if not name:
                continue  # scarta righe senza descrizione
            try:
                unit_of_measure = _to_str(sheet.cell_value(r, 1))
            except IndexError:
                unit_of_measure = ""
            try:
                unit_price = sheet.cell_value(r, 2)
            except IndexError:
                unit_price = 0.0
            try:
                discount = _to_str(sheet.cell_value(r, 3))
            except IndexError:
                discount = ""
            try:
                tax_raw = sheet.cell_value(r, 4)
            except IndexError:
                tax_raw = None

            tax_rate = _to_number(tax_raw, 22.0)
            if tax_rate == 0.0 and tax_raw in (None, ""):
                tax_rate = 22.0

            rows.append(
                {
                    "id": f"cat-{len(rows) + 1}",
                    "name": name,
                    "unitOfMeasure": unit_of_measure,
                    "currency": "E",
                    "unitPrice": _to_number(unit_price, 0.0),
                    "discount": discount,
                    "taxRate": tax_rate,
                }
            )
    return rows


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    input_path = Path(args[0]) if args else DEFAULT_INPUT
    output_path = Path(args[1]) if len(args) > 1 else DEFAULT_OUTPUT

    if not input_path.exists():
        print(f"Errore: file XLS non trovato: {input_path}", file=sys.stderr)
        return 1

    rows = build(input_path, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(rows, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"Scritte {len(rows)} voci -> {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())