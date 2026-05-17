# Domaine pilote — Création d'entreprise (Khidmaty Voice)

Base de connaissances **focalisée et auto-suffisante** pour répondre, par voix, à toutes les questions courantes d'un citoyen ou d'un entrepreneur mauritanien souhaitant créer une entreprise.

## Sources consolidées

- **APIM** (Agence de Promotion des Investissements en Mauritanie) — page « Création d'entreprise » et brochure officielle PDF d'octobre 2025.
- **procedures.gov.mr** (portail Ijraati) — fiche officielle n°790.

## Fichiers

| # | Fichier | Contenu | Source primaire |
|---|---|---|---|
| 01 | `01_apim_apercu.md` | Vue d'ensemble : 48h, 3 enregistrements bundlés, 4 formes juridiques, coûts | APIM page FR |
| 02 | `02_personne_physique.md` | Définition + dossier complet (8 pièces) + bases légales | PDF APIM |
| 03 | `03_personne_morale.md` | Définition + dossier complet (9 pièces) + particularités SARL/SA + bases légales | PDF APIM |
| 04 | `04_gie.md` | Définition GIE + dossier complet (11 pièces) + bases légales | PDF APIM |
| 05 | `05_succursale.md` | Définition + dossier variant A (mère physique) + variant B (mère morale) + bases légales | PDF APIM |
| 06 | `06_documents_universels.md` | Socle commun à toutes les formes + tableau comparatif des spécificités | APIM page FR |
| 07 | `07_faq.md` | 14 questions/réponses voice-friendly | APIM page FR enrichie |
| 08 | `08_contact_pratique.md` | Adresse, téléphones, email, plateforme Khidmaty, horaires indicatifs, paiement mobile banking | APIM + portail |
| 09 | `09_portal_summary.md` | Résumé officiel court tel que publié sur procedures.gov.mr | Portail Ijraati |
| — | `eval_questions.json` | 20 questions citoyens réalistes pour benchmark de retrieval | Construit pour Khidmaty Voice |

## Couverture vérifiée

L'eval set teste 20 intents distincts couvrant : délai, coût, documents par forme, en ligne / hors ligne, étrangers, différences SARL/individuelle, capital minimum, adresse, téléphone, paiement, succursale, GIE, rapatriement, bureau physique, conseil juridique, secteurs réglementés, ce que fait le Guichet Unique, bases légales.

## À noter

- Tout le contenu est en **français** — la langue d'usage du portail APIM. La traduction arabe peut se faire par l'LLM au moment de la réponse, en s'appuyant sur les chunks récupérés.
- Les **horaires d'ouverture** ne sont pas publiés officiellement ; le fichier 08 le signale honnêtement et invite à appeler.
- Les **comptes mobile banking** précis ne sont pas listés sur le site APIM ; le fichier 08 le signale et redirige vers le Guichet Unique.
- La fiche du portail (#790) est volontairement laissée comme **résumé court** — la profondeur vient des fichiers APIM.

## Prochaine étape

Charger ce dossier dans ChromaDB (collection `khidmaty_creation_entreprise`), puis exécuter `eval_questions.json` contre le retrieval pour mesurer le top-3 recall avant de brancher l'LLM voice.
