# Arabic / English Exam Question Generator — local RAG

A teacher picks a grade, a subject and some chapters; this service finds the right textbook passages and a **local LLM** writes exam questions grounded in them, then exports a ready-to-print **Word exam with an answer key** (right-to-left for Arabic). Nothing leaves the machine: retrieval, generation and export all run locally.

Built as my AI module for the *AI-Powered School Management System* senior project at Arab International University (2026).

## What it does

- **5 question types:** multiple choice, true/false, short answer, fill in the blank, essay
- **Bloom's taxonomy:** remember, understand, apply, analyze, evaluate, create; difficulty easy / medium / hard
- **Curriculum by name:** 23+ Syrian curriculum books are pre-indexed (~12k chunks), so a teacher selects a book and chapters with no upload
- **Any PDF:** unknown PDFs are parsed (with OCR where needed) and indexed in memory on the fly
- **Chapters, not page numbers:** chapters come from each book's table of contents, with a heuristic fallback
- **Quality checks:** every generated question gets a 0–100 score for structure, answer validity, readability and relevance to the source text
- **Known-book detection:** an uploaded PDF that matches an indexed textbook (by file hash, text hash or token overlap) reuses its existing chunks instead of running OCR again
- **Word export:** formatted `.docx` exam, RTL for Arabic and LTR for English, optional answer key

## How retrieval works

```
teacher request (book, chapters, counts, Bloom levels)
        │
        ├─► BM25 over Arabic-normalized tokens ─┐
        │                                       ├─► reciprocal rank fusion (k = 60) ─► top passages
        └─► dense search in Qdrant (bge-m3) ────┘
                                                      │
                                 local LLM via Ollama (command-r7b-arabic, custom Modelfile)
                                                      │
                                  questions + quality scores ─► .docx exam + answer key
```

- **Hybrid on purpose:** BM25 catches exact curriculum terms; dense vectors catch paraphrases. RRF merges the two ranked lists without needing to calibrate their scores.
- **Book-scoped:** questions can only be grounded in chunks from the chosen book and chapters, never a random passage from another subject.
- **Arabic normalization:** diacritics, alef variants, ta marbuta and ya/alef maqsura are normalized before indexing and search (`arabic_norm.py`).

## Run it

Prerequisites: Python 3.12 and [Ollama](https://ollama.com).

```bash
pip install -r requirements.txt
copy .env.example .env            # or: cp .env.example .env, then set AI_API_KEY

ollama pull command-r7b-arabic
ollama create smartschool -f Modelfile

python tools/build_index.py       # builds the BM25 + Qdrant index from your textbook chunks
uvicorn main:app --host 0.0.0.0 --port 8002
```

Textbooks and the prebuilt index are not included in this repo. See [`docs/INTEGRATION.md`](docs/INTEGRATION.md) for the full API contract and the frontend flow.

### API

All endpoints except `/health` and `/reference/types` need `X-API-Key: <AI_API_KEY>`.

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/books` | Indexed curriculum books with grade and subject |
| `GET` | `/books/{book}/chapters` | Chapters for one book |
| `POST` | `/questions/generate` | Generate questions for a book/chapters or an uploaded document |
| `POST` | `/questions/export/docx` | Export generated questions to Word |
| `POST` | `/questions/from-pdf` | Upload any PDF and get a Word exam back |
| `POST` | `/documents/upload` | Upload and index a PDF for later requests |

## Project layout

| File | What it does |
|---|---|
| `main.py` | FastAPI service and request validation |
| `retriever.py` | Book-scoped hybrid retrieval (BM25 + dense, RRF) |
| `index_store.py` | Loads the prebuilt BM25 index and the Qdrant collection |
| `question_engine.py` / `prompts.py` | Prompting the local LLM and parsing its output |
| `evaluator.py` | Automatic quality scoring of generated questions |
| `pdf_parser.py`, `toc_chapters.py`, `chapters.py` | PDF text extraction, OCR and chapter detection |
| `docx_exporter.py` | RTL/LTR Word export with answer key |
| `tools/` | Index building, OCR batch scripts and test harnesses |

## Stack

Python · FastAPI · Ollama · command-r7b-arabic · Qdrant · sentence-transformers (bge-m3) · rank-bm25 · PyMuPDF · EasyOCR · python-docx
