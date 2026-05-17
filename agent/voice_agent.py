"""LiveKit voice agent for Khidmaty Voice — bilingual FR + AR.

Pipeline per turn:
  Caller mic → Whisper STT (auto-detect FR/AR) → detect language from transcript
  → retrieve from the matching Qdrant collection → GPT-4o-mini (replies in same
  language as the question) → OpenAI TTS (multilingual voice).

Pre-retrieve: chunks are injected into the user message in `on_user_turn_completed`,
avoiding the LLM tool-call round-trip.

Run as a worker that auto-joins rooms in your LiveKit Cloud project:
    python agent/voice_agent.py dev
"""
import asyncio
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI as _OpenAIClient
from qdrant_client import QdrantClient

load_dotenv(Path(__file__).parent.parent / ".env")

for key in ("OPENAI_API_KEY", "QDRANT_URL", "QDRANT_API_KEY",
            "LIVEKIT_URL", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET"):
    if not os.environ.get(key):
        print(f"Missing {key} in .env"); sys.exit(1)

from livekit import agents
from livekit.agents import Agent, AgentSession, ChatContext, ChatMessage
from livekit.plugins import openai as lk_openai
from livekit.plugins import silero

_oai = _OpenAIClient(api_key=os.environ["OPENAI_API_KEY"])
_qd = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"], timeout=60)
TOP_K = 5

COLLECTIONS = {
    "fr": "khidmaty_creation_entreprise_fr",
    "ar": "khidmaty_creation_entreprise_ar",
}

SYSTEM_PROMPT = """Tu es Khidmaty Voice, l'assistant vocal officiel du Guichet Unique de l'APIM (Agence de Promotion des Investissements en Mauritanie). Tu réponds par téléphone à des citoyens et entrepreneurs mauritaniens qui veulent créer une entreprise, en français ou en arabe standard.

Chaque message utilisateur contient deux parties :
- Un bloc <contexte> avec des extraits officiels du corpus APIM, dans la langue de la question.
- Une ligne "Question du citoyen (LANG): ..." où LANG est 'fr' ou 'ar'.

Règles strictes :

1. Langue de réponse. Si LANG='fr', réponds en français. Si LANG='ar', réponds en arabe standard moderne. Ne mélange jamais les deux langues dans une même réponse.

2. Source unique. Réponds UNIQUEMENT à partir du bloc <contexte>. N'invente jamais une procédure, un montant, un délai, une loi, ou un document.

3. Refus si l'information manque dans <contexte> :
   - FR : "Je n'ai pas cette information précise. Contactez le Guichet Unique de l'APIM au +222 38 80 80 80."
   - AR : "لا أملك هذه المعلومة الدقيقة. الرجاء الاتصال مباشرة بالشباك الموحد لـ APIM على الرقم +222 38 80 80 80."

4. Style oral. Réponse parlée courte, 40 mots maximum. Pas de listes, pas de markdown, pas de numérotation. Phrases complètes prononçables par une voix.

5. Ton. Service public, poli, direct. Ne dis jamais "selon le document", "d'après le contexte", ni "selon les extraits".

6. Chiffres concrets en priorité. Pour un délai, un coût, un nombre de documents — commence par le chiffre.

7. Salutations et messages non-questions ("merci", "bonjour", "شكرا", "مرحبا"). Réponds brièvement et poliment dans la même langue, sans inventer de procédure.

8. Si la langue détectée n'est ni français ni arabe (par exemple anglais ou hassaniya), demande poliment en français de reformuler en français ou en arabe standard."""

GREETING = ("Bonjour, et bienvenue au service Khidmaty Voice de l'APIM. "
            "أهلا وسهلا بكم في خدمة Khidmaty Voice. "
            "Vous pouvez poser votre question en français ou en arabe. Comment puis-je vous aider ?")


def _detect_lang(text: str) -> str:
    """Pick 'ar' if the text is meaningfully Arabic, else 'fr'."""
    if not text:
        return "fr"
    arabic = sum(1 for c in text if "؀" <= c <= "ۿ")
    return "ar" if arabic / max(len(text), 1) > 0.2 else "fr"


def _retrieve_sync(query: str, collection: str) -> str:
    emb = _oai.embeddings.create(model="text-embedding-3-small", input=query).data[0].embedding
    hits = _qd.query_points(collection_name=collection, query=emb, limit=TOP_K).points
    if not hits:
        return "AUCUN EXTRAIT TROUVÉ."
    blocks = []
    for i, h in enumerate(hits, 1):
        p = h.payload
        blocks.append(f"[Extrait {i}] {p['heading_path']}\n{p['text']}")
    return "\n\n---\n\n".join(blocks)


class KhidmatyAgent(Agent):
    def __init__(self) -> None:
        super().__init__(instructions=SYSTEM_PROMPT)

    async def on_user_turn_completed(
        self, turn_ctx: ChatContext, new_message: ChatMessage
    ) -> None:
        user_text = (new_message.text_content or "").strip()
        if not user_text:
            return
        lang = _detect_lang(user_text)
        collection = COLLECTIONS[lang]
        chunks = await asyncio.to_thread(_retrieve_sync, user_text, collection)
        new_message.content = [
            f"<contexte>\n{chunks}\n</contexte>\n\nQuestion du citoyen ({lang}): {user_text}"
        ]


async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()

    # Seed Whisper with the domain vocabulary so auto-detect doesn't drift to English.
    stt_prompt = (
        "Question en français ou en arabe standard sur la création d'entreprise en "
        "Mauritanie. Vocabulaire: APIM, Khidmaty, Guichet Unique, SARL, GIE, "
        "succursale, NIF, CNSS, mobile banking, MRU. "
        "سؤال بالفرنسية أو العربية الفصحى حول إنشاء مؤسسة في موريتانيا. "
        "المفردات: APIM، الشباك الموحد، شركة، فرع، السجل التجاري، أوقية."
    )

    session = AgentSession(
        vad=silero.VAD.load(min_silence_duration=0.5),
        stt=lk_openai.STT(
            model="whisper-1",
            detect_language=True,
            prompt=stt_prompt,
        ),
        llm=lk_openai.LLM(model="gpt-4o-mini", temperature=0.2),
        # `shimmer` is multilingual and handles both FR and AR naturally.
        tts=lk_openai.TTS(model="tts-1", voice="shimmer"),
    )

    await session.start(room=ctx.room, agent=KhidmatyAgent())
    await session.generate_reply(instructions=f"Dis exactement: {GREETING}")


if __name__ == "__main__":
    agents.cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
