"""Query the Qdrant collection from the command line.

Usage:
    python rag/retrieve.py "Combien de temps pour creer une SARL ?"
    python rag/retrieve.py --lang ar "كم تستغرق المدة لإنشاء مؤسسة ؟"
    python rag/retrieve.py --k 3 "votre question"
"""
import argparse
import os
import sys

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient

load_dotenv()

LANGS = ["fr", "ar", "en"]

oai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
qd = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"], timeout=60)


def retrieve(query: str, collection: str, top_k: int = 5):
    emb = oai.embeddings.create(model="text-embedding-3-small", input=query).data[0].embedding
    return qd.query_points(collection_name=collection, query=emb, limit=top_k).points


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", choices=LANGS, default="fr")
    parser.add_argument("--k", type=int, default=5, help="number of hits (default 5)")
    parser.add_argument("query", nargs="+", help="the question text")
    args = parser.parse_args()

    collection = f"khidmaty_creation_entreprise_{args.lang}"
    query = " ".join(args.query)
    print(f"Q ({args.lang}): {query}\n")
    hits = retrieve(query, collection=collection, top_k=args.k)
    if not hits:
        print("(no results — is the collection populated? run rag/ingest.py)")
        sys.exit(0)

    for i, h in enumerate(hits, 1):
        p = h.payload
        snippet = p["text"][:220].replace("\n", " ")
        print(f"[{i}] score={h.score:.3f}  {p['file']}  ->  {p['heading_path']}")
        print(f"    {snippet}{'...' if len(p['text']) > 220 else ''}\n")


if __name__ == "__main__":
    main()
