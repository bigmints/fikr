---
trigger: always_on
---

- Make sure to use all latest compatiable and stable version of flutter and packages.
- Don't complete a task without running "flutter analyze" and fixing linter errors
- Use firebase CLI to manage firebase configurations

The app has 4 plans

1 - Free (Bring your own API Key)
2 - Plus (Bring your own API Key + Cloud Sync using firebase auth and firestore )
3 - Pro (Vertext AI with usage limits + Cloud Sync using firebase and firestore )

When a free basic user becomes a plus or pro, the local data must sync to firestore)

- A remoe config will define what models are selected for Analysis and Transcription : Open AI, Gemini, and Vertex
