# BrainAI Setup Guide

## Prerequisites

Before building BrainAI, ensure you have the following installed:

### Required

- **macOS 14.0 (Sonoma)** or later
- **Xcode 15.4+** with command-line tools
- **Swift 5.10+** (included with Xcode)

### For Runtime

- **Python 3.10+** - Required for LightRAG server
- **Ollama** - Required for local LLM inference (optional if using cloud-only providers)

## Installation Methods

### Method 1: Installer (Recommended)

Download and run the BrainAI Installer app. It will detect your system configuration and install missing components automatically.

### Method 2: Manual Setup

#### 1. Install Ollama

```bash
# Via Homebrew
brew install ollama

# Or download from https://ollama.com
```

#### 2. Pull Required Models

```bash
# Language model (choose based on your RAM)
ollama pull qwen2.5:7b      # 8 GB RAM
ollama pull qwen2.5:14b     # 16 GB RAM
ollama pull qwen2.5:32b     # 32 GB+ RAM

# Embedding model (required)
ollama pull nomic-embed-text
```

#### 3. Install LightRAG

```bash
pip3 install --user lightrag-hku
```

#### 4. Build BrainAI

```bash
cd BrainAI
swift package resolve
swift build -c release
```

#### 5. Launch

The built executables will be in `.build/release/`. Run:

```bash
.build/release/BrainAITray    # Menu bar agent
.build/release/BrainAIApp     # Main UI
```

## Development Setup

### IDE

We recommend using Xcode. From the repository root open `BrainAI/Package.swift`; if your checkout is only the Swift package, open `Package.swift` in its directory.

### Running Tests

```bash
cd BrainAI
swift test
```

### Project Structure

Canonical documentation lives under **`BrainAI/docs/`** (this file, architecture, diagrams, landing page). In a wrapper checkout, the repo-root **`docs/`** directory holds symlinks to the same files for backward-compatible URLs and GitHub Pages.

Swift package layout:

```
BrainAI/
  Package.swift
  Sources/
    BrainAICore/          # Shared library
    BrainAIApp/           # Main UI
    BrainAITray/          # Menu bar agent
    BrainAISettings/      # Settings
    BrainAIInstaller/     # Setup wizard
  Tests/
    BrainAICoreTests/     # Unit tests
  docs/                   # Documentation (canonical)
    SETUP.md
    ARCHITECTURE.md
    ...
  Entitlements/           # Code signing entitlements
```

In a monorepo layout, **`scripts/`**, **`.github/`**, and **`Makefile`** often sit next to **`BrainAI/`** — see the repository root `README.md`.

## Configuration

### Environment Variables (for development)

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_HOST` | Ollama API host | `localhost` |
| `OLLAMA_PORT` | Ollama API port | `11434` |
| `LIGHTRAG_HOST` | LightRAG API host | `localhost` |
| `LIGHTRAG_PORT` | LightRAG API port | `9621` |

### API Keys

Cloud provider API keys can be set in the Settings app or during the Installer wizard. They are stored in the macOS Keychain under the `com.brainai` service identifier.

## Troubleshooting

### Ollama not starting

Check that Ollama is installed and the service is running:

```bash
ollama serve
```

### LightRAG connection issues

Verify LightRAG is running on the expected port:

```bash
curl http://localhost:9621/health
```

### Build errors

Ensure all dependencies are resolved:

```bash
cd BrainAI
swift package resolve
swift package clean
swift build
```
