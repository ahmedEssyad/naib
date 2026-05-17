"""Answer a French question by retrieving top-K chunks and asking GPT for a
voice-style response grounded in the corpus.

Usage:
    python rag/answer.py "Combien ça coûte une SARL ?"
    python rag/answer.py --show-context "ou est l'APIM ?"
"""
import argparse
import os
import sys

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient

load_dotenv()

for key in ("OPENAI_API_KEY", "QDRANT_URL", "QDRANT_API_KEY"):
    if not os.environ.get(key):
        print(f"Missing {key} in .env"); sys.exit(1)

oai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
qd = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"], timeout=60)
COLLECTION = os.environ["QDRANT_COLLECTION"]

EMBED_MODEL = "text-embedding-3-small"
CHAT_MODEL = "gpt-4o-mini"
TOP_K = 5
MAX_OUTPUT_TOKENS = 200

SYSTEM_PROMPT = """Tu es Khidmaty Voice, l'assistant vocal officiel du Guichet Unique de l'APIM (Agence de Promotion des Investissements en Mauritanie). Tu réponds par téléphone à des citoyens et entrepreneurs mauritaniens qui veulent créer une entreprise.

Règles strictes:

1. Source unique. Réponds UNIQUEMENT à partir des extraits fournis dans <contexte>. N'invente jamais une procédure, un montant, un délai, une loi, ou un document.

2. Si l'information manque dans <contexte>, réponds exactement: "Je n'ai pas cette information précise. Pour cette question, contactez directement le Guichet Unique de l'APIM au +222 38 80 80 80 ou à info-apim@apim.gov.mr."

3. Style oral. Réponse parlée, courte, 40 mots maximum. Pas de listes à puces, pas de markdown, pas de numérotation. Phrases complètes que la voix peut prononcer naturellement.

4. Ton. Service public, poli, direct. Ne dis jamais "selon le document" ni "d'après le contexte" — donne la réponse comme un agent qui connaît la procédure.

5. Chiffres concrets en priorité. Si la question porte sur un délai, un coût, ou un nombre de documents, commence par le chiffre.

6. Langue. Réponds en français."""


def retrieve(query: str, k: int = TOP_K):
    emb = oai.embeddings.create(model=EMBED_MODEL, input=query).data[0].embedding
    return qd.query_points(collection_name=COLLECTION, query=emb, limit=k).points


def build_user_message(question: str, hits) -> str:
    blocks = []
    for i, h in enumerate(hits, 1):
        p = h.payload
        blocks.append(f"[Extrait {i}] {p['heading_path']}\n{p['text']}")
    context = "\n\n---\n\n".join(blocks)
    return f"<contexte>\n{context}\n</contexte>\n\nQuestion du citoyen: {question}"


def answer(question: str, k: int = TOP_K):
    hits = retrieve(question, k=k)
    user_msg = build_user_message(question, hits)
    resp = oai.chat.completions.create(
        model=CHAT_MODEL,
        max_tokens=MAX_OUTPUT_TOKENS,
        temperature=0.2,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
    )
    return resp.choices[0].message.content.strip(), hits, resp.usage


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--k", type=int, default=TOP_K)
    parser.add_argument("--show-context", action="store_true")
    parser.add_argument("question", nargs="+")
    args = parser.parse_args()

    question = " ".join(args.question)
    print(f"Q: {question}\n")

    text, hits, usage = answer(question, k=args.k)
    print(f"A: {text}\n")

    words = len(text.split())
    print(f"(words: {words}  |  in_tokens: {usage.prompt_tokens}  out_tokens: {usage.completion_tokens})\n")

    print("Sources:")
    seen = set()
    for h in hits:
        f = h.payload["file"]
        if f not in seen:
            seen.add(f)
            print(f"  - {f}  ::  {h.payload['heading_path']}")

    if args.show_context:
        print("\n--- Retrieved context ---")
        for i, h in enumerate(hits, 1):
            p = h.payload
            print(f"\n[Extrait {i}] score={h.score:.3f}  {p['file']} -> {p['heading_path']}")
            print(p["text"][:500] + ("..." if len(p["text"]) > 500 else ""))


if __name__ == "__main__":
    main()
