"""Run eval_questions.json against the retrieval pipeline and score.

Metrics:
  - file_recall@3 : fraction of expected_files that appear in the top-3 distinct files retrieved
  - must_contain  : fraction of must_contain strings that appear in the top-K retrieved text
                    (case-insensitive substring; top-K = 5 by default)

Usage: python rag/eval.py [--lang fr|ar|en]   (default: fr)
"""
import argparse
import json
import os
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient

load_dotenv()

LANG_DIRS = {
    "fr": "khidmaty_creation_entreprise",
    "ar": "khidmaty_creation_entreprise_ar",
    "en": "khidmaty_creation_entreprise_en",
}
TOP_K = 5

oai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
qd = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"], timeout=60)


def retrieve(query: str, collection: str, top_k: int = TOP_K):
    emb = oai.embeddings.create(model="text-embedding-3-small", input=query).data[0].embedding
    return qd.query_points(collection_name=collection, query=emb, limit=top_k).points


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=sorted(LANG_DIRS), default="fr")
    args = parser.parse_args()

    eval_file = Path(__file__).parent.parent / LANG_DIRS[args.lang] / "eval_questions.json"
    collection = f"khidmaty_creation_entreprise_{args.lang}"

    data = json.loads(eval_file.read_text(encoding="utf-8"))
    items = data["items"]

    print(f"Running {len(items)} eval questions against collection '{collection}'\n")
    print(f"{'ID':<5} {'file@3':>7} {'must_c':>7}  Question")
    print("-" * 100)

    total_fr = 0.0
    total_mc = 0.0
    perfect_fr = 0
    per_q = []

    for item in items:
        qid = item["id"]
        question = item["question"]
        expected = set(item["expected_files"])
        must = item["must_contain"]

        hits = retrieve(question, collection=collection, top_k=TOP_K)

        # distinct top-3 files in retrieval order
        seen = []
        for h in hits:
            f = h.payload["file"]
            if f not in seen:
                seen.append(f)
            if len(seen) == 3:
                break
        top3 = set(seen)

        file_recall = len(expected & top3) / len(expected) if expected else 1.0

        combined = " ".join(h.payload["text"] for h in hits).lower()
        hit_strings = [s for s in must if s.lower() in combined]
        mc_rate = len(hit_strings) / len(must) if must else 1.0

        total_fr += file_recall
        total_mc += mc_rate
        if file_recall == 1.0:
            perfect_fr += 1

        q_short = question if len(question) <= 60 else question[:57] + "..."
        print(f"{qid:<5} {file_recall*100:>6.0f}% {mc_rate*100:>6.0f}%  {q_short}")

        per_q.append({
            "id": qid,
            "question": question,
            "file_recall": file_recall,
            "must_contain_rate": mc_rate,
            "top3_files": seen,
            "missing_files": sorted(expected - top3),
            "missing_strings": [s for s in must if s.lower() not in combined],
        })

    n = len(items)
    print("-" * 100)
    print(f"\nSummary over {n} questions:")
    print(f"  Avg file_recall@3 : {total_fr / n * 100:.1f}%")
    print(f"  Avg must_contain  : {total_mc / n * 100:.1f}%")
    print(f"  Perfect file recall: {perfect_fr}/{n}")

    failures = [q for q in per_q if q["file_recall"] < 1.0 or q["must_contain_rate"] < 1.0]
    if failures:
        print(f"\n--- {len(failures)} question(s) with partial misses ---")
        for q in failures:
            print(f"\n[{q['id']}] {q['question']}")
            print(f"  top-3 files retrieved : {q['top3_files']}")
            if q["missing_files"]:
                print(f"  MISSING expected files: {q['missing_files']}")
            if q["missing_strings"]:
                print(f"  MISSING must_contain  : {q['missing_strings']}")


if __name__ == "__main__":
    main()
