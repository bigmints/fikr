---
description: Update the Fikr Tool Integration Catalog (tools.md) by parsing the codebase
---

# Update Tool Catalog Workflow

This workflow ensures the Fikr Tool Integration Catalog (`.agents/knowledge/fikr/tools.md`) stays perfectly in sync with the actual Dart implementations in the Flutter app.

## Steps

1. **Scan Domain Files**
   Identify all domain tool files in `fikr/lib/tools/tools/` (e.g., `ai_tools.dart`, `notes_tools.dart`).

2. **Extract Tool Metadata**
   For each file, extract every `FikrTool` implementation. For each tool, you must collect:
   - **Name**: e.g., `String get name => 'notes.create';`
   - **Description**: e.g., `String get description => '...';` (un-wrap multi-line strings)
   - **Required Tier**: e.g., `ToolTier get requiredTier => ToolTier.free;`
   - **Parameters**: Review `parametersSchema` to understand the inputs (optional to document, but helpful for context).

3. **Format the Catalog**
   Format the extracted data into a clean Markdown document.
   - Start with a title and a short introduction stating the total number of tools.
   - Group tools by Domain (derived from the file name, e.g., `notes_tools.dart` -> `## Domain: NOTES`).
   - Use H3 `###` for each tool name (e.g., `### notes.create`).
   - Include the **Description** and **Required Plan Tier** for each tool.

4. **Update `tools.md`**
   Completely overwrite `.agents/knowledge/fikr/tools.md` with the newly generated markdown content.

5. **Update AGENTS.md**
   Check `AGENTS.md` to ensure the tool count in the knowledge base table (under `fikr` / `tools.md`) matches the new total. Update it if necessary.

6. **Report**
   Report the total number of tools documented and any new domains discovered.
