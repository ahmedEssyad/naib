"""Sanity check: connect to Qdrant Cloud and OpenAI, list collections.

Run after filling .env:  python rag/check_qdrant.py
"""
import os
import sys

from dotenv import load_dotenv
from openai import OpenAI
from qdrant_client import QdrantClient

load_dotenv()


def require(name: str) -> str:
    val = os.getenv(name)
    if not val or val.startswith("sk-...") or val.startswith("https://xxxx"):
        print(f"FAIL: {name} is missing or still a placeholder in .env")
        sys.exit(1)
    return val


openai_key = require("OPENAI_API_KEY")
qdrant_url = require("QDRANT_URL")
qdrant_key = require("QDRANT_API_KEY")

print("Checking OpenAI...")
oai = OpenAI(api_key=openai_key)
emb = oai.embeddings.create(model="text-embedding-3-small", input="bonjour").data[0].embedding
print(f"  OK — embedding dim = {len(emb)}")

print("Checking Qdrant Cloud...")
qd = QdrantClient(url=qdrant_url, api_key=qdrant_key, timeout=60)
collections = qd.get_collections().collections
print(f"  OK — connected. {len(collections)} existing collection(s): {[c.name for c in collections]}")

print("\nAll good. You're ready to ingest.")
