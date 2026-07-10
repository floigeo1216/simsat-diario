#!/usr/bin/env python3
"""
Regenera anp-catalog.js a partir de ANP232.csv.

Uso:
    python3 scripts/build_catalog.py

Ejecuta este script cada vez que ANP232.csv cambie (nuevos decretos,
recategorizaciones, correcciones de nombre, etc.) y luego haz commit
tanto del CSV como del anp-catalog.js regenerado.
"""
import csv
import json
import pathlib

HERE = pathlib.Path(__file__).parent
CSV_PATH = HERE / "ANP232.csv"
OUT_PATH = HERE.parent / "anp-catalog.js"

CAT_LABELS = {
    "RB": "Reserva de la Biosfera",
    "PN": "Parque Nacional",
    "APFF": "Área de Protección de Flora y Fauna",
    "APRN": "Área de Protección de Recursos Naturales",
    "MN": "Monumento Natural",
    "SANT": "Santuario",
}


def build():
    rows = []
    with open(CSV_PATH, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cat = row["CAT_MANEJO"].strip()
            if cat not in CAT_LABELS:
                raise ValueError(
                    f"Categoría desconocida '{cat}' en {row['ID_ANP']} "
                    f"({row['NOMBRE']}). Agrégala a CAT_LABELS en este script."
                )
            rows.append({
                "id": row["ID_ANP"].strip(),
                "name": row["NOMBRE"].strip(),
                "cat": cat,
                "catLabel": CAT_LABELS[cat],
                "estados": row["ESTADOS"].strip(),
                "region": row["REGION"].strip(),
            })

    rows.sort(key=lambda r: r["name"])

    catalog_json = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
    labels_json = json.dumps(CAT_LABELS, ensure_ascii=False, separators=(",", ":"))

    content = (
        "// Catálogo de Áreas Naturales Protegidas (CONANP), generado de ANP232.csv\n"
        "// NO EDITAR A MANO: ejecuta `python3 scripts/build_catalog.py` para regenerar.\n"
        f"export const ANP_CATALOG = {catalog_json};\n"
        f"export const ANP_CAT_LABELS = {labels_json};\n"
    )

    OUT_PATH.write_text(content, encoding="utf-8")
    print(f"OK: {len(rows)} ANP escritas en {OUT_PATH}")


if __name__ == "__main__":
    build()
