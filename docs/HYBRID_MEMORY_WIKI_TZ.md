# BrainAI Hybrid Memory Wiki ТЗ

Дата: 2026-05-01
Статус: архитектурное ТЗ для стадии разработки

## 1. Цель

BrainAI должен стать не просто оболочкой над LightRAG, а общей памятью пользователя: локальной, долгоживущей, проверяемой, человекочитаемой и доступной из приложения, MCP-клиентов и будущих агентов.

Целевая парадигма: **LightRAG отвечает за retrieval/graph engine, LLM Wiki отвечает за компилируемый слой знания**.

Итоговая система должна хранить:

- сырые источники как неизменяемую правду;
- LightRAG-граф, embeddings, chunks и retrieval-индексы как машинный индекс;
- Markdown Wiki как человекочитаемый “compiled memory” слой;
- журнал решений, противоречий, обновлений и пользовательских ревью;
- общую память, доступную из BrainAI UI, tray, settings, MCP и внешних AI-инструментов.

## 2. Исходные методы

### 2.1 LightRAG

LightRAG дает BrainAI сильный backend для поиска:

- chunking документов;
- embedding/vector retrieval;
- entity/relation extraction;
- knowledge graph;
- query modes: `local`, `global`, `hybrid`, `naive`, `mix`, `bypass`;
- structured context через `/query/data`;
- graph API: labels, search, subgraph, create/edit/merge entity, create/edit relation;
- document status pipeline;
- workspace isolation.

Сильная сторона LightRAG: быстро и машинно находить релевантный контекст в больших корпусах.

Слабая сторона для “личной памяти”: знание остается в основном индексом, графом и чанками. Пользователь не получает устойчивый, редактируемый, читаемый слой “что мы теперь знаем”.

### 2.2 LLM Wiki Karpathy

LLM Wiki предлагает другой акцент:

- `raw/` содержит неизменяемые источники;
- `wiki/` содержит LLM-generated Markdown страницы;
- `schema` файл задает правила поддержания wiki;
- ingest не только индексирует источник, а обновляет существующие страницы;
- query может породить новый wiki-артефакт;
- lint ищет противоречия, stale claims, orphan pages, missing links.

Сильная сторона LLM Wiki: знание компаундится в человекочитаемую базу, которую можно открыть, проверить, версионировать и редактировать.

Слабая сторона: без retrieval/graph backend она быстрее упирается в масштаб, качество поиска, дубли сущностей и сложные связи.

## 3. Вывод

BrainAI не должен выбирать “LightRAG или Wiki”. Лучший вариант: **двухконтурная память**.

```
Raw Sources
    |
    v
Ingestion Orchestrator
    |
    +--> LightRAG Index: chunks, embeddings, KG, document status
    |
    +--> Wiki Compiler: markdown pages, backlinks, summaries, contradictions
    |
    v
Memory Query Router
    |
    +--> Wiki-first answers for stable knowledge
    +--> LightRAG retrieval for evidence, discovery, long-tail search
    +--> Hybrid synthesis for final answers
```

## 4. Продуктовое определение

BrainAI Hybrid Memory Wiki — это локальная персональная wiki, которую пользователь читает и ревьюит, а LLM поддерживает. LightRAG остается машинным retrieval engine под ней.

Главная UX-идея:

- пользователь добавляет источники, заметки, ссылки, файлы, разговоры;
- BrainAI показывает, что было извлечено;
- BrainAI предлагает изменения wiki;
- пользователь может принять, отклонить, поправить или пометить как “автоматически доверять для этого workspace”;
- все ответы AI могут быть сохранены как wiki page или decision note;
- любая wiki-страница имеет источники, связи, историю и confidence.

## 5. Целевая структура workspace

Каждый workspace должен иметь единый каталог памяти:

```text
~/Library/Application Support/BrainAI/Workspaces/{workspace}/
  raw/
    documents/
    notes/
    chats/
    clips/
    assets/
  lightrag/
    rag_storage/
    input/
    logs/
  wiki/
    index.md
    log.md
    overview.md
    inbox/
    entities/
    concepts/
    sources/
    syntheses/
    decisions/
    contradictions/
    questions/
    user/
  schema/
    MEMORY_SCHEMA.md
    page_templates/
  metadata/
    source_manifest.json
    wiki_manifest.json
    review_queue.json
    sync_state.json
```

## 6. Слои архитектуры

### 6.1 Raw Source Store

Назначение: неизменяемый источник истины.

Требования:

- сохранять оригинал файла или текстового источника;
- присваивать стабильный `source_id`;
- хранить checksum, импортный путь, дату, MIME type, workspace;
- не редактировать raw автоматически;
- поддержать заметки пользователя как raw source, но позволить им быть mutable через отдельную версионность.

### 6.2 LightRAG Engine

Назначение: машинный retrieval и graph extraction.

Использовать существующие возможности:

- `/documents/text`, `/documents/upload`, `/documents/track_status/{track_id}`;
- `/query` для ответа;
- `/query/data` для структурированного retrieval context;
- `/graphs`, `/graph/label/search`, `/graph/label/list`;
- `/graph/entity/create`, `/graph/relation/create`, `/graph/entities/merge`;
- workspace routing через `LIGHTRAG-WORKSPACE`.

Нужно доработать BrainAI:

- добавить workspace header в `HTTPClient`/`LightRAGClient`;
- расширить DTO под актуальный LightRAG `/query/data`;
- добавить методы `trackStatus`, `uploadDocument`, `mergeEntities`, `editEntity`, `editRelation`;
- научить Documents UI показывать track_id, file_path, errors, chunks_count.

### 6.3 Wiki Compiler

Назначение: превращать raw + LightRAG context в Markdown pages.

Компоненты:

- `WikiCompilerService` в BrainAICore;
- `WikiPageStore` для файлового чтения/записи;
- `WikiManifestStore` для индекса страниц;
- `WikiReviewQueue` для pending изменений;
- `WikiLintService` для здоровья базы.

Wiki Compiler не должен напрямую “верить” LLM. Он создает patch/proposal, который проходит quality gate.

### 6.4 Memory Query Router

Назначение: выбрать источник ответа.

Режимы:

- `wiki`: искать только в compiled wiki;
- `rag`: искать через LightRAG;
- `hybrid`: сначала wiki, затем LightRAG для evidence и недостающих деталей;
- `deep`: wiki + LightRAG `/query/data` + graph neighborhood + synthesis writeback;
- `raw`: показать исходники без генерации.

Рекомендуемый default: `hybrid`.

### 6.5 Review and Governance

Назначение: не дать памяти загрязниться.

Каждое изменение wiki имеет статус:

- `draft`;
- `needs_review`;
- `accepted`;
- `rejected`;
- `superseded`;
- `auto_accepted`.

Для личной памяти нужен переключатель по workspace:

- strict: все wiki edits через review;
- assisted: авто-принятие низкорисковых source summary, ревью для syntheses/decisions;
- autonomous: авто-принятие всего, но с rollback/log.

## 7. Типы wiki-страниц

### 7.1 Source Page

Путь: `wiki/sources/{source_slug}.md`

Назначение: краткая карта конкретного источника.

Frontmatter:

```yaml
type: source
source_id: src_...
status: accepted
created_at: 2026-05-01T00:00:00Z
updated_at: 2026-05-01T00:00:00Z
confidence: medium
light_rag_doc_id: doc-...
tags: []
```

Секции:

- TLDR;
- Key claims;
- Entities;
- Relations;
- Open questions;
- Links to concepts;
- Citations.

### 7.2 Entity Page

Путь: `wiki/entities/{entity_slug}.md`

Секции:

- Definition;
- Known facts;
- Relationships;
- Timeline;
- Contradictions;
- Sources;
- Related pages.

### 7.3 Concept Page

Путь: `wiki/concepts/{concept_slug}.md`

Секции:

- Definition;
- Why it matters;
- How it relates to user goals/projects;
- Examples;
- Competing interpretations;
- Sources.

### 7.4 Synthesis Page

Путь: `wiki/syntheses/{topic_slug}.md`

Назначение: обобщение нескольких источников.

Секции:

- Thesis;
- Supporting evidence;
- Counter-evidence;
- Confidence;
- What changed since previous version;
- Follow-up questions.

### 7.5 Decision Page

Путь: `wiki/decisions/{date}-{decision_slug}.md`

Назначение: долговременная память решений.

Секции:

- Decision;
- Context;
- Alternatives considered;
- Why now;
- Consequences;
- Revisit trigger;
- Sources/discussion links.

### 7.6 User Memory Page

Путь: `wiki/user/{topic}.md`

Назначение: предпочтения, цели, постоянные факты пользователя.

Требования:

- повышенная приватность;
- явное подтверждение для чувствительных фактов;
- возможность “forget this”;
- разделение facts/preferences/goals/constraints.

## 8. Ingestion Pipeline

### 8.1 Базовый flow

1. Пользователь добавляет источник.
2. BrainAI сохраняет raw copy и manifest.
3. BrainAI отправляет источник в LightRAG.
4. BrainAI отслеживает processing status.
5. После success BrainAI вызывает `/query/data` с ingest prompts для извлечения структурированного контекста.
6. Wiki Compiler создает proposed patch:
   - source page;
   - entity/concept updates;
   - backlinks;
   - contradictions;
   - questions.
7. Quality Gate проверяет patch.
8. Review UI показывает изменения.
9. После accept изменения пишутся в `wiki/`, `wiki/index.md`, `wiki/log.md`.

### 8.2 Quality Gate

Patch отклоняется или уходит на ревью, если:

- нет источников/citations;
- есть claims без source_id;
- затрагивается user memory;
- меняется decision page;
- confidence ниже threshold;
- обнаружено противоречие;
- LLM предлагает удалить или переписать много страниц;
- источник является дубликатом.

### 8.3 Writeback после query

Если пользователь получил полезный ответ, BrainAI предлагает:

- сохранить как synthesis;
- сохранить как decision;
- добавить в concept page;
- добавить в user memory;
- ничего не сохранять.

## 9. Query Pipeline

### 9.1 Hybrid answer

1. Search wiki manifest/index.
2. Read top wiki pages.
3. Query LightRAG `/query/data` для evidence.
4. Pull graph neighborhood для ключевых сущностей.
5. Synthesize answer with citations.
6. Отдельно показать:
   - “из wiki”;
   - “из raw/LightRAG”;
   - “неуверенно/требует проверки”.
7. Предложить writeback.

### 9.2 Когда использовать wiki-first

- пользователь спрашивает “что мы решили”;
- “что я предпочитаю”;
- “какой текущий статус проекта”;
- “напомни договоренности”;
- “что мы знаем о X”.

### 9.3 Когда использовать LightRAG-first

- новый исследовательский вопрос;
- поиск по длинным документам;
- вопрос требует точной цитаты;
- wiki еще не скомпилирована;
- нужно найти источник, а не синтез.

## 10. UI требования

### 10.1 Новый раздел Wiki

Добавить в BrainAIApp раздел `Wiki`.

Виды:

- Index;
- Recently updated;
- Review queue;
- Contradictions;
- Entities;
- Concepts;
- Decisions;
- User Memory;
- Source browser.

### 10.2 Страница wiki

Функции:

- Markdown preview/edit;
- backlinks;
- source citations;
- related LightRAG graph;
- history/log;
- “Ask about this page”;
- “Recompile from sources”;
- “Open raw source”;
- “Accept/reject suggested edits”.

### 10.3 Ingestion Review

Показывать patch diff:

- created pages;
- updated pages;
- deleted/superseded claims;
- new entities;
- new relations;
- contradictions.

## 11. MCP требования

Существующий MCP BrainAI нужно расширить.

Новые tools:

- `brainai_wiki_search(query, workspace?)`;
- `brainai_wiki_get_page(path_or_slug, workspace?)`;
- `brainai_wiki_get_context(topic, depth?, workspace?)`;
- `brainai_wiki_ingest_source(path_or_text, source_type, workspace?)`;
- `brainai_wiki_propose_update(instruction, pages?, workspace?)`;
- `brainai_wiki_accept_update(proposal_id, workspace?)`;
- `brainai_memory_remember(fact, category, sensitivity?, workspace?)`;
- `brainai_memory_forget(selector, workspace?)`;
- `brainai_memory_query(question, mode?, workspace?)`;
- `brainai_lint_memory(scope?, workspace?)`.

Старые tools `brainai_query`, `brainai_insert`, `brainai_search` оставить для совместимости, но внутри направлять через Memory Query Router.

## 12. Data Model в Swift

Добавить модели:

- `MemoryWorkspace`;
- `RawSource`;
- `WikiPage`;
- `WikiPageKind`;
- `WikiFrontmatter`;
- `WikiPatch`;
- `WikiPatchOperation`;
- `WikiReviewItem`;
- `WikiBacklink`;
- `MemoryQueryMode`;
- `MemoryQueryResult`;
- `Contradiction`;
- `DecisionRecord`;
- `UserMemoryFact`.

Минимальные поля `WikiPage`:

```swift
public struct WikiPage: Codable, Identifiable, Sendable {
    public let id: UUID
    public var path: String
    public var slug: String
    public var title: String
    public var kind: WikiPageKind
    public var frontmatter: WikiFrontmatter
    public var markdown: String
    public var backlinks: [WikiBacklink]
    public var sourceIDs: [String]
    public var updatedAt: Date
}
```

## 13. Storage and Sync

Markdown wiki должна быть обычной файловой системой, не скрытой базой.

Обязательные свойства:

- можно открыть в Obsidian/VS Code;
- можно версионировать Git;
- можно экспортировать zip;
- можно восстановить index из файлов;
- LightRAG storage можно пересоздать из raw + wiki;
- wiki не должна зависеть от одного embedding model.

## 14. Privacy and Safety

Так как цель — общая память пользователя:

- raw и wiki по умолчанию локальные;
- API keys только Keychain;
- user memory facts требуют уровней чувствительности;
- чувствительные страницы исключаются из MCP по умолчанию;
- remote LightRAG должен иметь workspace-scoped auth;
- нужен audit log для memory changes;
- нужна команда forget с удалением из wiki, manifest, LightRAG и cache where possible.

## 15. Оценка смены парадигмы

Рекомендация: **сменить парадигму сейчас**, пока проект в разработке.

Не менять:

- SwiftUI macOS-first подход;
- LightRAG как backend;
- multi-target architecture;
- MCP направление;
- локальность и provider roles.

Изменить:

- BrainAI должен стать не “RAG app”, а “Memory OS for user knowledge”;
- Documents/Notes/Chat/Graph должны сходиться в Wiki/Memory;
- query должен быть не только retrieval, но и потенциальный wiki writeback;
- ingestion должен заканчивать не только индексом, но и compiled wiki proposal;
- UI должен показывать знание как страницы, решения, связи и противоречия.

## 16. Roadmap

### Phase 0. Архитектурная подготовка

- Зафиксировать workspace folder layout.
- Добавить `docs/HYBRID_MEMORY_WIKI_TZ.md` как базовое ТЗ.
- Определить Memory Query Router API.
- Обновить README/ARCHITECTURE после утверждения.

### Phase 1. Wiki filesystem MVP

- `WikiPageStore`: read/write/list markdown.
- YAML frontmatter parser/writer.
- `wiki/index.md` generator.
- `wiki/log.md` append-only writer.
- Новый UI раздел Wiki с read-only preview.

### Phase 2. LightRAG sync MVP

- Добавить workspace header в LightRAG HTTP calls.
- Добавить track status.
- Расширить `/query/data` DTO.
- Source manifest связывает raw source, LightRAG doc_id, wiki source page.

### Phase 3. Wiki Compiler MVP

- Source summary generation.
- Entity/concept page proposals.
- Review queue.
- Accept/reject patches.
- Basic contradiction page.

### Phase 4. Hybrid Query

- Memory Query Router.
- Wiki-first search.
- LightRAG evidence retrieval.
- Hybrid answer with citations.
- Save answer to wiki.

### Phase 5. MCP Memory

- Новые wiki/memory tools.
- Permissions по workspace и sensitivity.
- Context bundle endpoint/tool для агентов.

### Phase 6. Health and Scale

- Wiki lint.
- Orphan pages.
- stale claims.
- duplicate entity merge.
- local markdown search index.
- optional Git versioning.

## 17. Критерии успеха

MVP успешен, если:

- пользователь добавляет документ;
- LightRAG индексирует его;
- BrainAI создает wiki source page;
- BrainAI предлагает entity/concept updates;
- пользователь принимает изменения;
- вопрос по теме отвечает с wiki + LightRAG citations;
- ответ можно сохранить как synthesis/decision;
- MCP-клиент видит ту же память.

V1 успешен, если:

- BrainAI можно использовать как долговременную память между сессиями;
- wiki читается без приложения;
- LightRAG storage можно пересоздать;
- пользователь видит, откуда взялся каждый важный claim;
- система умеет находить противоречия и просить ревью.

## 18. Риски

### 18.1 Загрязнение памяти

Риск: LLM будет записывать неверные claims.

Митигация: review queue, source citations, confidence, strict mode.

### 18.2 Слишком много страниц

Риск: wiki станет шумной.

Митигация: source page всегда, entity/concept только при повторяемости или важности.

### 18.3 Дубли сущностей

Риск: LightRAG и wiki будут расходиться.

Митигация: entity merge UI, aliases, canonical slug, graph lint.

### 18.4 Конфликт личной рефлексии и автоматизации

Риск: LLM заменит мышление пользователя.

Митигация: разделить справочную память и рефлексивные заметки. Для `wiki/user/` и journal-like контента включить review-by-default.

### 18.5 Сложность продукта

Риск: BrainAI превратится в слишком сложную систему.

Митигация: один clear UX: Raw -> Index -> Wiki -> Ask -> Remember.

## 19. Архитектурное решение

Принять гибрид:

1. **LightRAG остается обязательным retrieval/graph ядром.**
2. **Markdown Wiki становится главным пользовательским артефактом памяти.**
3. **BrainAI Core получает Memory layer поверх LightRAG.**
4. **Все UI-разделы сходятся к общей памяти.**
5. **MCP открывает не только RAG tools, а полноценные memory/wiki tools.**

Это дает максимум преимуществ обоих методов: масштабируемый поиск LightRAG и накопительное, проверяемое, человекочитаемое знание LLM Wiki.

## 20. Источники исследования

- Andrej Karpathy, `llm-wiki.md`: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- Open-source LLM Wiki implementation overview: https://llmwiki.app/
- LightRAG local source: `/Users/eugenbrezhnev/dev_soft/LightRAG-main`
- BrainAI local source: `/Users/eugenbrezhnev/dev_soft/brainAI_develop/BrainAI`
