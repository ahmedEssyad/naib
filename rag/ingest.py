"""Chunk a language corpus, embed with OpenAI, upsert into Qdrant.

Run: python rag/ingest.py [--lang fr|ar|en]   (default: fr)
"""
import argparse
import os
import re
import sys
from collections import Counter
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.http import models as qm

load_dotenv()

LANG_DIRS = {
    "fr": "khidmaty_creation_entreprise",
    "ar": "khidmaty_creation_entreprise_ar",
    "en": "khidmaty_creation_entreprise_en",
}
EMBED_MODEL = "text-embedding-3-small"
EMBED_DIM = 1536

oai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
qd = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"], timeout=60)


def _derive_heading(block: str) -> str:
    """Pull a human-readable heading from a chunk: H2, bold question, or first non-empty line."""
    m = re.search(r"^##\s+(.+)$", block, re.MULTILINE)
    if m:
        return m.group(1).strip()
    m = re.search(r"^\*\*(Q\d+\.\s*[^*]+)\*\*", block, re.MULTILINE)
    if m:
        return m.group(1).strip().rstrip("?").strip() + "?"
    m = re.search(r"^\*\*([^*]+)\*\*", block, re.MULTILINE)
    if m:
        return m.group(1).strip()
    for line in block.splitlines():
        s = line.strip()
        if s and not s.startswith(("SOURCE", "ORGANISME", "DATE_", "---")):
            return s[:80]
    return ""


def parse_file(path: Path):
    """Return (h1_title, source_url, [(heading, chunk_text), ...]).

    Splits on `---` horizontal rules when there are 3+ of them (FAQ-style); otherwise
    splits on H2 (`## `). Falls back to a single chunk if neither pattern is present.
    """
    text = path.read_text(encoding="utf-8")

    h1_match = re.search(r"^#\s+(.+)$", text, re.MULTILINE)
    h1 = h1_match.group(1).strip() if h1_match else path.stem

    src_match = re.search(r"^SOURCE:\s*(\S+)", text, re.MULTILINE)
    source_url = src_match.group(1).strip() if src_match else ""

    hr_matches = list(re.finditer(r"^---\s*$", text, re.MULTILINE))
    if len(hr_matches) >= 3:
        boundaries = [0] + [m.end() for m in hr_matches] + [len(text)]
        raw_blocks = [text[boundaries[i]:boundaries[i + 1]].strip().lstrip("-").strip()
                      for i in range(len(boundaries) - 1)]
        chunks = [(_derive_heading(b), b) for b in raw_blocks if b]
        return h1, source_url, chunks

    h2_positions = [(m.start(), m.group(1).strip())
                    for m in re.finditer(r"^##\s+(.+)$", text, re.MULTILINE)]
    if not h2_positions:
        return h1, source_url, [("", text.strip())]

    chunks = []
    for i, (start, heading) in enumerate(h2_positions):
        end = h2_positions[i + 1][0] if i + 1 < len(h2_positions) else len(text)
        chunks.append((heading, text[start:end].strip()))
    return h1, source_url, chunks


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=sorted(LANG_DIRS), default="fr")
    args = parser.parse_args()

    corpus_dir = Path(__file__).parent.parent / LANG_DIRS[args.lang]
    collection = f"khidmaty_creation_entreprise_{args.lang}"

    md_files = sorted(p for p in corpus_dir.glob("*.md") if p.name != "INDEX.md")
    if not md_files:
        print(f"No markdown files in {corpus_dir}")
        sys.exit(1)
    print(f"Lang: {args.lang}  →  collection '{collection}'")
    print(f"Found {len(md_files)} files in {corpus_dir.name}/")

    points_data = []
    next_id = 0
    for path in md_files:
        h1, source_url, chunks = parse_file(path)
        for chunk_idx, (heading, chunk_text) in enumerate(chunks):
            heading_path = f"{h1} / {heading}" if heading else h1
            # Prepend H1 to the text we embed so each chunk carries document context.
            embed_input = f"{h1}\n\n{chunk_text}"
            points_data.append({
                "id": next_id,
                "embed_input": embed_input,
                "payload": {
                    "file": path.name,
                    "heading_path": heading_path,
                    "text": chunk_text,
                    "source_url": source_url,
                    "chunk_index": chunk_idx,
                },
            })
            next_id += 1
    print(f"Built {len(points_data)} chunks")

    print(f"Embedding with {EMBED_MODEL}...")
    resp = oai.embeddings.create(model=EMBED_MODEL, input=[p["embed_input"] for p in points_data])
    vectors = [d.embedding for d in resp.data]
    print(f"  Got {len(vectors)} embeddings (dim {len(vectors[0])})")

    if qd.collection_exists(collection):
        print(f"Dropping existing collection '{collection}'...")
        qd.delete_collection(collection)
    qd.create_collection(
        collection_name=collection,
        vectors_config=qm.VectorParams(size=EMBED_DIM, distance=qm.Distance.COSINE),
    )
    qd.upsert(
        collection_name=collection,
        points=[qm.PointStruct(id=p["id"], vector=v, payload=p["payload"])
                for p, v in zip(points_data, vectors)],
    )
    print(f"Upserted {len(points_data)} points into '{collection}'.\n")

    counts = Counter(p["payload"]["file"] for p in points_data)
    print("Chunks per file:")
    for fname, n in sorted(counts.items()):
        print(f"  {n:3d}  {fname}")


if __name__ == "__main__":
    main()
