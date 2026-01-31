# GPT-OSS DeepResearch Evaluation

Evaluation framework for deep research agents with local/remote search engines and multiple LLM backends.

---

## Table of Contents

- [Data Preparation](#data-preparation)
- [Installation](#installation)
- [Configuration](#configuration)
- [Get Started](#get-started)
- [Benchmarks](#benchmarks)
- [Script Parameters](#script-parameters)
- [Evaluation](#evaluation)

---

## Data Preparation

### Option A: Using Serper API (Recommended for Quick Start)

If you only need to run evaluations using **Serper API** for web search, you only need to configure API keys:

```bash
cp .env.template .env
```

Edit `.env`:
```bash
# Serper API (for web search)
SERPER_API_KEY=your_serper_api_key    # Get from: https://serper.dev/

# OpenAI API (for evaluation)
OPENAI_API_KEY=your_openai_api_key    # Get from: https://platform.openai.com/
```

This is sufficient for running evaluations on: `hle`, `gaia`, `webwalkerqa`, `xbench`, `seal`.

### Option B: Local Search Engine (For BrowseComp-Plus)

To run **BrowseComp-Plus** benchmark with local search, you need to download the corpus and indexes:

**1. Download BrowseComp-Plus Corpus:**
```bash
# Create data directory
mkdir -p Tevatron/browsecomp-plus-corpus/data
mkdir -p Tevatron/browsecomp-plus-indexes

# Download corpus (parquet files)
huggingface-cli download OpenResearcher/browsecomp-plus-corpus \
    --repo-type dataset \
    --local-dir Tevatron/browsecomp-plus-corpus
```

**2. Download Search Indexes:**
```bash
# BM25 Index (lightweight, recommended)
huggingface-cli download OpenResearcher/browsecomp-plus-indexes \
    --repo-type dataset \
    --include "bm25/*" \
    --local-dir Tevatron/browsecomp-plus-indexes

# Dense Index (optional, requires GPU)
huggingface-cli download OpenResearcher/browsecomp-plus-indexes \
    --repo-type dataset \
    --include "qwen3-embedding-8b/*" \
    --local-dir Tevatron/browsecomp-plus-indexes
```

**3. Download Lucene JARs (for BM25 highlighting):**
```bash
mkdir -p tevatron
cd tevatron
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-highlighter/9.9.1/lucene-highlighter-9.9.1.jar
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-queries/9.9.1/lucene-queries-9.9.1.jar
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-memory/9.9.1/lucene-memory-9.9.1.jar
cd ..
```

---

## Installation

### Quick Setup (Recommended)

Run the setup script to install all dependencies automatically:

```bash
bash setup.sh
```

**This script will:**
- Install Python 3.12 virtual environment using `uv`
- Install all Python dependencies
- Install Tevatron for local search
- Download Lucene JARs
- Download corpus and indexes (optional, interactive)

### Manual Installation

**1. Install system dependencies:**
```bash
sudo apt install -y openjdk-21-jdk
```

**2. Install Python dependencies:**
```bash
uv sync
```

**3. Install Tevatron (for BrowseComp-Plus local search):**
```bash
git clone https://github.com/texttron/tevatron.git
cd tevatron
uv pip install -e .
cd ..
```

**4. Download Lucene JARs:**
```bash
mkdir -p tevatron
cd tevatron
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-highlighter/9.9.1/lucene-highlighter-9.9.1.jar
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-queries/9.9.1/lucene-queries-9.9.1.jar
wget https://repo1.maven.org/maven2/org/apache/lucene/lucene-memory/9.9.1/lucene-memory-9.9.1.jar
cd ..
```

---

## Configuration

### API Keys

Copy the template and configure your API keys:

```bash
cp .env.template .env
```

Edit `.env`:
```bash
# Serper API (for web search when using browser_backend=serper)
SERPER_API_KEY=your_key        # Get from: https://serper.dev/

# OpenAI API (for evaluation scoring)
OPENAI_API_KEY=your_key        # Get from: https://platform.openai.com/api-keys
```

---

## Get Started

### Example 1: BrowseComp-Plus with Local Search Engine

**Complete workflow using local BM25 search:**

```bash
# Terminal 1: Start local BM25 search service on port 8000
bash scripts/start_search_service.sh bm25 8000

# Terminal 2: Start vLLM servers (requires 4 GPUs)
# TP=2, deploy 2 servers starting from port 8001 on GPUs 0,1,2,3
bash scripts/start_nemotron_servers.sh 2 8001 0,1,2,3

# Terminal 3: Run agent
bash run_agent.sh \
    results/browsecomp_plus/OpenResearcher \
    8001 \
    2 \
    browsecomp_plus \
    local \
    OpenResearcher/Nemotron-3-Nano-30B-A3B
```

**What this does:**
- Deploys BM25 search on port 8000 as virtual search engine
- Launches 2 vLLM servers (ports 8001, 8002) with TP=2 across 4 GPUs
- Runs agent with load balancing across both servers

### Example 2: Using Serper API (No Local Search Needed)

**Run with Serper Google Search API:**

```bash
# Terminal 1: Start vLLM servers (requires 4 GPUs)
bash scripts/start_nemotron_servers.sh 2 8001 0,1,2,3

# Terminal 2: Run agent with serper search backend
bash run_agent.sh \
    results/gaia/OpenResearcher_serper \
    8001 \
    2 \
    gaia \
    serper \
    OpenResearcher/Nemotron-3-Nano-30B-A3B
```

**Browser Backend Options:**
- `local` - Use local BM25/Dense search service (for BrowseComp-Plus)
- `serper` - Use Serper Google Search API (for all other benchmarks)

---

## Benchmarks

| Benchmark | Dataset Key | Size | Language | Search Backend | Description |
|-----------|-------------|------|----------|----------------|-------------|
| **BrowseComp-Plus** | `browsecomp_plus` | 830 | EN | local | Deep-research benchmark isolating retriever and LLM agent effects |
| **HLE** | `hle` | 2,158 | EN | serper | Multiple choice questions from Humanity's Last Exam |
| **GAIA-text** | `gaia` | 103 | EN | serper | Text-only subset of GAIA benchmark (dev split) |
| **WebWalkerQA** | `webwalkerqa` | 680 | EN | serper | Web navigation and interaction questions (test split) |
| **WebWalkerQA-ref** | `webwalkerqa_ref` | 680 | EN | serper | With reference URLs in question |
| **XBench** | `xbench` | 100 | ZH | serper | DeepSearch benchmark with encrypted test cases |
| **SealQA** | `seal` | 111 | EN | serper | Hardest subset of SealQA questions |
| **SealQA-ref** | `seal_ref` | 111 | EN | serper | With reference URLs |

### Quick Commands

| Scenario | Command |
|----------|---------|
| **BrowseComp+ (BM25)** | `bash scripts/start_search_service.sh bm25 8000` then `bash run_agent.sh results/bc 8001 2 browsecomp_plus local <model>` |
| **BrowseComp+ (Dense)** | `bash scripts/start_search_service.sh dense 8000` then `bash run_agent.sh results/bc 8001 2 browsecomp_plus local <model>` |
| **HLE** | `bash run_agent.sh results/hle 8001 2 hle serper <model>` |
| **GAIA** | `bash run_agent.sh results/gaia 8001 2 gaia serper <model>` |
| **WebWalkerQA** | `bash run_agent.sh results/webwalker 8001 2 webwalkerqa serper <model>` |
| **XBench** | `bash run_agent.sh results/xbench 8001 2 xbench serper <model>` |
| **SealQA** | `bash run_agent.sh results/seal 8001 2 seal serper <model>` |

---

## Script Parameters

### run_agent.sh

```bash
bash run_agent.sh [output_dir] [base_port] [num_servers] [dataset_name] [browser_backend] [model_path]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `output_dir` | `results/browsecomp/output` | Output directory for results |
| `base_port` | `8002` | Base port number for vLLM servers |
| `num_servers` | `3` | Number of vLLM servers to use |
| `dataset_name` | `browsecomp` | Dataset key (see Benchmarks table) |
| `browser_backend` | `local` | `local` or `serper` |
| `model_path` | `OpenResearcher/Nemotron-3-Nano-30B-A3B` | Model name or path |

### scripts/start_nemotron_servers.sh

```bash
bash scripts/start_nemotron_servers.sh [tensor_parallel_size] [base_port] [cuda_visible_devices] [model_path]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `tensor_parallel_size` | `2` | Number of GPUs per server |
| `base_port` | `8001` | Base port number for servers |
| `cuda_visible_devices` | `0,1,2,3,4,5,6,7` | Comma-separated GPU IDs |
| `model_path` | (see script) | Model name or path |

### scripts/start_search_service.sh

```bash
bash scripts/start_search_service.sh [searcher_type] [port] [cuda_visible_devices]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `searcher_type` | `dense` | `bm25` or `dense` |
| `port` | `8000` | Port for search service |
| `cuda_visible_devices` | `0` | GPU ID for dense searcher (ignored for BM25) |

---

## Evaluation

After running experiments, evaluate results:

```bash
python eval.py --input_dir results/browsecomp_plus/OpenResearcher
```

---

## Project Structure

```
.
├── run_agent.sh                 # Main agent runner
├── setup.sh                     # One-click setup script
├── deploy_agent.py              # Agent orchestration
├── browser.py                   # Browser tool backends
├── data_utils.py                # Dataset loaders
├── eval.py                      # Evaluation script
├── .env.template                # API keys template
├── scripts/
│   ├── start_search_service.sh  # Start local search service
│   ├── start_nemotron_servers.sh # Start vLLM servers
│   ├── stop_servers.sh          # Stop all servers
│   ├── deploy_search_service.py # Search service implementation
│   └── deploy_vllm_service.py   # vLLM service wrapper
└── utils/
    ├── openai_generator.py      # OpenAI API generator
    └── vllm_generator.py        # Local vLLM generator
```

## License

