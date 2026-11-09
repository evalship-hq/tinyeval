---
type: tool_order
before: { tool: Bash, input_match: '\./tinyeval(?! -[vh])' }
after: { tool: Edit, input_match: 'bot\.py' }
---
The evals ran before the prompt changed.
