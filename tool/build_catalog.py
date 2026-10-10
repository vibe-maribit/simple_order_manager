#!/usr/bin/env python3
"""Genera `assets/catalog/catalogo.json` dal listino fornito in #25.

Legge l'XLSX `corretto.10.2026.xlsx` (zip con `xl/sharedStrings.xml` e
`xl/worksheets/sheet1.xml`) e produce un array JSON compatto con un oggetto
per riga (la prima riga è l'intestazione):

    {
      "id": "cat-<n>",
      "name": "Descrizione (colonna A)",
      "unitOfMeasure": "Unità di misura (colonna B)",
      "currency": "Divisa (colonna C, `E`)",
      "unitPrice": Prezzo (colonna D, `,` -> `.`),
      "discount": "Sconti (colonna E)",
      "taxRate": IVA (colonna F, vuota -> 22.0)
    }

Nessuna dipendenza esterna: solo la standard library. Gli id `cat-<n>` sono
stabili (ordinale della riga), così l'asset è riproducibile in modo
deterministico.
"""

from __future__ import annotations

import html
import json
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = ROOT / "tool" / "catalogo" / "corretto.10.2026.xlsx"
DEFAULT_OUTPUT = ROOT / "assets" / "catalog" / "catalogo.json"


def _shared_strings(sheet_zip: zipfile.ZipFile) -> list[str]:
    """Estrae il vettore `sharedStrings.xml` in testi decodificati."""
    with sheet_zip.open("xl/sharedStrings.xml") as fh:
        xml = fh.read().decode("utf-8")
    return [
        html.unescape("".join(re.findall(r"<t[^>]*>(.*?)</t>", si, re.S)))
        for si in re.findall(r"<si>(.*?)</si>", xml, re.S)
    ]


def _rows(sheet_zip: zipfile.ZipFile) -> list[re.Match[str]]:
    with sheet_zip.open("xl/worksheets/sheet1.xml") as fh:
        xml = fh.read().decode("utf-8")
    return re.findall(r'<row[^>]*r="(\d+)"[^>]*>(.*?)</row>', xml, re.S)


def _cell_values(r: str, strings: list[str]) -> dict[str, str | None]:
    """Mappa colonna -> valore testuale per una riga della scheda."""
    cells: dict[str, str | None] = {}
    for cell in re.findall(r"<c [^>]*>.*?</c>", r, re.S):
        col = re.match(r'<c r="([A-Z]+)', cell).group(1)
        v = re.search(r"<v>(.*?)</v>", cell)
        raw = v.group(1) if v else None
        if raw is None:
            cells[col] = None
            continue
        t = re.search(r't="([^"]+)"', cell)
        if t and t.group(1) == "s":
            cells[col] = strings[int(raw)]
        else:
            cells[col] = raw
    return cells


def _to_number(raw: str | None, fallback: float = 0.0) -> float:
    """`1.234,56` -> `1234.56`; stringa o assente -> [fallback] (arrotondato).

    I prezzi dell'XLSX sono numerici ma talvolta scontano artefatti in virgola
    mobile (`295.85000000000002`): l'arrotondamento a 2 decimali ripristina
    il valore tabellare (l'Italia è a un prezzo su 2 decimali).
    """
    if raw is None:
        return fallback
    try:
        value = float(raw.strip().replace(",", "."))
    except ValueError:
        return fallback
    return round(value, 2)


def build(input_path: Path = DEFAULT_INPUT, output_path: Path = DEFAULT_OUTPUT) -> list[dict]:
    rows: list[dict] = []
    with zipfile.ZipFile(input_path) as sheet_zip:
        strings = _shared_strings(sheet_zip)
        for row_no, r in _rows(sheet_zip):
            # Riga 1 = intestazione (Descrizione, Unità di Misura, Divisa,
            # Prezzo, Sconti, IVA).
            if row_no == "1":
                continue
            cells = _cell_values(r, strings)
            name = (cells.get("A") or "").strip()
            if not name:
                continue
            rows.append(
                {
                    "id": f"cat-{len(rows) + 1}",
                    "name": name,
                    "unitOfMeasure": (cells.get("B") or "").strip(),
                    "currency": (cells.get("C") or "E").strip(),
                    "unitPrice": _to_number(cells.get("D"), 0.0),
                    "discount": (cells.get("E") or "").strip(),
                    # IVA vuota -> aliquota ordinaria italiana (22%).
                    "taxRate": _to_number(cells.get("F"), 22.0),
                }
            )
    return rows


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    input_path = Path(args[0]) if args else DEFAULT_INPUT
    output_path = Path(args[1]) if len(args) > 1 else DEFAULT_OUTPUT

    if not input_path.exists():
        print(f"Errore: file XLSX non trovato: {input_path}", file=sys.stderr)
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