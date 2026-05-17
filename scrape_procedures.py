"""
Scraper for procedures.gov.mr (Ijraati) — Mauritanian administrative procedures portal.

Targets the 10 topics required by the Khidmaty Voice RAG knowledge base. For each
topic we scrape every related fiche (variant) so the assistant can answer
"renew vs lose vs first-time" questions accurately.

Site is server-rendered HTML. Detail URL = /fr/procedure/{id}.
Per-topic fiche ids were enumerated via /fr/rechercher/motcle?motcle=<keyword>.
"""
from __future__ import annotations
import json
import re
import sys
import time
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path

import requests
from bs4 import BeautifulSoup

BASE = "https://procedures.gov.mr"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
    ),
    "Accept-Language": "fr,ar;q=0.9,en;q=0.8",
}
DELAY = 1.5
OUT_DIR = Path(__file__).parent / "output"
OUT_DIR.mkdir(exist_ok=True)

# Topic families. Each entry: (topic_slug, [(fiche_id, short_label_for_filename), ...]).
# Fiche ids verified by manual probing of the portal's search index.
FAMILIES: list[tuple[str, list[tuple[str, str]]]] = [
    ("creation_entreprise", [
        ("790",  "creation"),
        ("691",  "enregistrement_onmt"),
        ("1676", "declaration_fiscale"),
    ]),
    ("carte_nationale_identite", [
        ("1119", "premiere_fois"),
        ("1123", "renouvellement"),
        ("1120", "perte"),
        ("1121", "abimee"),
        ("1122", "rectification"),
        ("1580", "validite_moins_6_mois"),
    ]),
    ("casier_judiciaire", [
        ("268",  "bulletin_n3"),
    ]),
    ("carte_grise", [
        ("290",  "vehicule_neuf"),
        ("292",  "occasion_etranger"),
        ("294",  "vehicule_reforme"),
        ("296",  "mutation"),
        ("309",  "renouvellement"),
        ("312",  "duplicata"),
    ]),
    ("connexion_somelec", []),  # placeholder topic — no fiche on portal
    ("permis_de_conduire", [
        ("316",  "obtention"),
        ("324",  "renouvellement"),
        ("323",  "duplicata"),
        ("325",  "authenticite"),
        ("326",  "transformation_etranger"),
        ("752",  "retrait_restitution"),
    ]),
    ("inscription_universite_nouakchott", [
        ("39",   "bourse_inscription_libre"),
        ("48",   "attestation_fin_etudes"),
        ("51",   "legalisation_diplomes"),
        ("925",  "transferts_etudiants"),
    ]),
    ("extrait_de_naissance", [
        ("1628", "certificat_naissance"),
        ("1704", "declaration_naissance"),
        ("264",  "statut_personnel"),
        ("1503", "extrait_chn"),
        ("1193", "naissance_etranger"),
        ("1204", "approbation_acte_etranger"),
        ("955",  "reconnaissance"),
    ]),
    ("passeport", [
        ("1588", "premiere_fois"),
        ("1589", "renouvellement"),
        ("1585", "perte"),
        ("1583", "abime"),
        ("1586", "rectification"),
        ("226",  "residents_etranger"),
        ("1216", "valise_diplomatique"),
    ]),
    ("registre_de_commerce", [
        ("265",  "inscription"),
    ]),
]

# Label-to-key map for the procedure detail rows (French labels lowercased,
# matched by substring).
LABEL_MAP = {
    "description de la procédure ou du service":         "DESCRIPTION",
    "description de la procédure":                       "DESCRIPTION",
    "documents requis":                                  "DOCUMENTS_REQUIS",
    "entité chargée de la procédure":                    "BUREAU_RESPONSABLE",
    "entité chargée de la réception de la demande":      "BUREAU_RECEPTION",
    "entités chargées du traitement de la demande":      "BUREAU_TRAITEMENT",
    "entité chargée de fournir la prestation demandée":  "BUREAU_PRESTATION",
    "délai de traitement":                               "DELAI",
    "frais afférents à la procédure":                    "FRAIS",
    "entité chargée de recevoir les réclamations":       "BUREAU_RECLAMATIONS",
    "contact":                                           "CONTACT",
    "bases juridiques et réglementaires de la procédure":"BASES_JURIDIQUES",
    "usagers de la procédure":                           "USAGERS",
    "étapes de la procédure":                            "ETAPES",
    "etapes de la procédure":                            "ETAPES",
    "étapes":                                            "ETAPES",
}

session = requests.Session()
session.headers.update(HEADERS)


def get(url: str) -> str:
    time.sleep(DELAY)
    r = session.get(url, timeout=30)
    r.raise_for_status()
    r.encoding = r.apparent_encoding or "utf-8"
    return r.text


@dataclass
class Fiche:
    topic: str
    variant: str
    procedure_id: str
    source_url: str
    title_fr: str = ""
    fields: dict = field(default_factory=dict)
    status: str = "ok"
    note: str = ""


def clean(s: str) -> str:
    if not s:
        return ""
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\s*\n\s*", "\n", s)
    return s.strip()


def parse_detail(html: str) -> tuple[str, dict]:
    soup = BeautifulSoup(html, "lxml")
    title = ""
    for p in soup.find_all("p"):
        if "font-size:21px" in p.get("style", "").replace(" ", ""):
            for span in p.find_all("span"):
                span.decompose()
            title = p.get_text(" ", strip=True)
            break
    fields: dict[str, list[str]] = {}
    for row in soup.select("table.table-striped tr"):
        label_div = row.find("div")
        if not label_div:
            continue
        label = re.sub(r"\s+", " ", label_div.get_text(" ", strip=True).lower()).strip()
        key = None
        for known, norm in LABEL_MAP.items():
            if known in label:
                key = norm
                break
        if not key:
            continue
        values = [p.get_text(" ", strip=True) for p in row.select("p.p_response")]
        values = [v for v in values if v]
        fields.setdefault(key, []).extend(values)
    flat = {k: (v[0] if len(v) == 1 else v) for k, v in fields.items()}
    return title, flat


def fetch_fiche(topic: str, variant: str, fid: str) -> Fiche:
    url = f"{BASE}/fr/procedure/{fid}"
    f = Fiche(topic=topic, variant=variant, procedure_id=fid, source_url=url)
    try:
        html = get(url)
        title, fields = parse_detail(html)
        f.title_fr = title
        f.fields = fields
        if not fields:
            f.status = "empty"
            f.note = "Detail table produced no fields."
    except Exception as e:
        f.status = "error"
        f.note = repr(e)
    return f


def format_record(f: Fiche, topic_label: str) -> str:
    fld = f.fields

    def joinlist(v):
        if isinstance(v, list):
            return clean(", ".join(v))
        return clean(v or "")

    docs_raw = fld.get("DOCUMENTS_REQUIS", "")
    if isinstance(docs_raw, list):
        docs = "\n  - " + "\n  - ".join(clean(d) for d in docs_raw)
    elif docs_raw:
        parts = [clean(p) for p in re.split(r"\s*[•·]\s*", str(docs_raw)) if clean(p)]
        docs = ("\n  - " + "\n  - ".join(parts)) if len(parts) > 1 else clean(docs_raw)
    else:
        docs = "non spécifié sur la fiche officielle"

    etapes_raw = fld.get("ETAPES", "")
    if etapes_raw:
        if isinstance(etapes_raw, list):
            etapes = "\n".join(f"  {i+1}. {clean(s)}" for i, s in enumerate(etapes_raw))
        else:
            etapes = f"  1. {clean(etapes_raw)}"
    else:
        etapes = ("  (le portail procedures.gov.mr ne publie pas d'étapes pour cette procédure ; "
                  "voir DOCUMENTS_REQUIS et BUREAU_RESPONSABLE pour le parcours réel)")

    bureau = joinlist(fld.get("BUREAU_RESPONSABLE", ""))
    extras = []
    for k, lbl in (("BUREAU_RECEPTION", "Réception"), ("BUREAU_TRAITEMENT", "Traitement"), ("BUREAU_PRESTATION", "Délivrance")):
        v = joinlist(fld.get(k, ""))
        if v and v != bureau:
            extras.append(f"{lbl} : {v}")
    if extras:
        bureau = f"{bureau} | " + " | ".join(extras)

    out = [
        f"TOPIC: {topic_label}",
        f"VARIANT: {f.variant}",
        f"PROCEDURE: {clean(f.title_fr)}",
        f"PROCEDURE_AR: {clean(f.title_fr)}  (le portail n'a pas de titre arabe distinct ; "
        f"les valeurs sur /ar/procedure/{f.procedure_id} sont identiques au français)",
    ]
    if fld.get("DESCRIPTION"):
        out.append(f"DESCRIPTION: {joinlist(fld['DESCRIPTION'])}")
    out += [
        f"DOCUMENTS_REQUIS: {docs}",
        f"ETAPES:\n{etapes}",
        f"DELAI: {joinlist(fld.get('DELAI', 'non spécifié'))}",
        f"BUREAU_RESPONSABLE: {bureau or 'non spécifié'}",
        f"FRAIS: {joinlist(fld.get('FRAIS', 'non spécifié'))}",
        f"USAGERS: {joinlist(fld.get('USAGERS', ''))}",
        f"CONTACT: {joinlist(fld.get('CONTACT', ''))}",
        f"BASES_JURIDIQUES: {joinlist(fld.get('BASES_JURIDIQUES', ''))}",
        f"SOURCE_URL: {f.source_url}",
        f"DATE_SCRAPED: {date.today().isoformat()}",
    ]
    if f.note:
        out.append(f"NOTE: {f.note}")
    return "\n".join(out) + "\n"


def placeholder_record(topic: str, topic_label: str, note: str) -> str:
    return (
        f"TOPIC: {topic_label}\n"
        f"VARIANT: placeholder\n"
        f"PROCEDURE: {topic_label}\n"
        f"STATUS: placeholder\n"
        f"NOTE: {note}\n"
        f"SOURCE_URL: n/a\n"
        f"DATE_SCRAPED: {date.today().isoformat()}\n"
        f"# Needs manual entry from outside the procedures.gov.mr portal.\n"
    )


def main():
    index = []
    report_lines = [
        "Khidmaty Voice — Scraping Report",
        "=" * 40,
        f"Date: {date.today().isoformat()}",
        f"Source: {BASE}",
        "Method: requests + BeautifulSoup (server-rendered HTML).",
        "Coverage: every relevant fiche per topic (not just the headline variant).",
        "",
    ]
    total_ok = 0
    total_files = 0

    for ti, (topic, variants) in enumerate(FAMILIES, start=1):
        topic_dir = OUT_DIR / f"{ti:02d}_{topic}"
        topic_dir.mkdir(exist_ok=True)
        topic_label = topic.replace("_", " ")
        print(f"\n[{ti:02d}] {topic}  ({len(variants)} fiche{'s' if len(variants)!=1 else ''})")

        if topic == "connexion_somelec":
            note = ("SOMELEC electricity-connection procedures are not published on procedures.gov.mr. "
                    "Verified by probing the portal search for 'somelec', 'electricite', 'electrique', "
                    "'branchement', 'raccordement', 'compteur', 'abonnement' — none returns an "
                    "electricity-utility fiche. Source must be somelec.mr or a counter visit.")
            fname = topic_dir / "00_placeholder.txt"
            fname.write_text(placeholder_record(topic, topic_label, note), encoding="utf-8")
            print(f"     wrote placeholder")
            index.append({
                "topic_rank": ti, "topic": topic, "variant": "placeholder",
                "procedure_id": None, "title_fr": None,
                "filename": str(fname.relative_to(OUT_DIR)),
                "source_url": None, "status": "placeholder",
            })
            report_lines.append(f"[{ti:02d}] {topic}: placeholder — {note[:80]}…")
            total_files += 1
            continue

        for vi, (fid, variant) in enumerate(variants, start=1):
            f = fetch_fiche(topic, variant, fid)
            fname = topic_dir / f"{vi:02d}_{variant}.txt"
            fname.write_text(format_record(f, topic_label), encoding="utf-8")
            ok = f.status == "ok" and bool(f.fields)
            total_ok += 1 if ok else 0
            total_files += 1
            mark = "ok" if ok else f.status
            print(f"     [{vi:02d}] id={fid:>5}  {mark:8}  {f.title_fr[:70]}")
            index.append({
                "topic_rank": ti, "topic": topic, "variant": variant,
                "procedure_id": fid, "title_fr": f.title_fr,
                "filename": str(fname.relative_to(OUT_DIR)),
                "source_url": f.source_url, "status": f.status,
            })
            report_lines.append(f"[{ti:02d}.{vi:02d}] {topic}/{variant:25s} id={fid:>5}  {mark:8}  {f.title_fr}")

    (OUT_DIR / "procedures_index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    report_lines.insert(6, f"Topics: {len(FAMILIES)}  |  Fiches scraped: {total_ok}/{total_files - 1}  "
                           f"(+1 documented placeholder for SOMELEC)")
    (OUT_DIR / "scraping_report.txt").write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print(f"\nDone. {total_files} files in {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())
