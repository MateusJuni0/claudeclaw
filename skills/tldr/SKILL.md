---
name: tldr
description: Summarize the current conversation into a TLDR note and save it to your notes folder. Use when you say "tldr", "save a summary", "note this convo", or want to capture key takeaways from the current session for future reference.
user_invocable: true
---

# /tldr -- Conversation Summary to Notes

When invoked, follow these steps exactly:

## Step 1: Summarize the conversation

Look at the last 5-10 back-and-forths in the current conversation. Write a TLDR that captures the **substance** of what was discussed, not just a log of actions taken.

The note should be useful to someone (including your future self) who wasn't in the conversation. They should be able to read it and understand the ideas, decisions, and reasoning -- not just "we did X, Y, Z."

Structure the summary into these sections:

- **Key ideas and content** -- The actual substance. If you discussed a video structure, include the structure. If you brainstormed titles, include the top candidates and why. If you designed an architecture, describe it. This is the most important section -- preserve the thinking, not just the actions.
- **Decisions made** -- What was decided and why. Include the reasoning, not just the conclusion.
- **Actions taken** -- Files created, commands run, things built. Keep this part brief -- just a reference list.
- **Open threads** -- Anything left unfinished or flagged for later.

The key ideas section should be the longest. Be specific -- include names, numbers, structures, frameworks, exact titles, quotes, timestamps. If you spent 20 minutes working through a video script structure, the TLDR should contain that structure, not just "discussed video structure."

## Step 2: Ask where to store it

Use AskUserQuestion to ask the user where this note should live. Present folder options based on their notes structure.

If the user has an Obsidian vault configured in CLAUDE.md (look for the `obsidian.vault` path), scan its top-level folders and present them as options. If no vault is configured, ask the user for a target directory.

Always include a generic **Inbox** option for unsorted notes.

Also show the proposed note title (auto-generated from the conversation topic) and let the user override it if they want.

Format the question like:

```
TLDR ready. Where should I save it?

Proposed title: "TLDR -- [Topic]"
(Reply with a different title if you want to rename it)
```

Then show the folder options.

## Step 3: Save the note

Once the user picks a folder (and optionally a custom title), create the note at:

```
[NOTES_DIR]/[Folder]/[Title].md
```

Use this format for the note content:

```markdown
---
type: tldr
created: YYYY-MM-DD
---

# [Title]

## Key Ideas

[The substance of the conversation. Preserve the actual content -- structures, frameworks, titles, reasoning, specific details. This section should be long enough that someone reading it gets the real value without needing the full conversation.]

## Decisions

[What was decided and why. Brief but include reasoning.]

## Actions Taken

[Brief list of concrete things done -- files created, commands run, etc. Just references.]

## Open Threads

[Anything unfinished or flagged for later.]

## Context

- **Session date**: [today's date]
- **Key files touched**: [list any files that were created/edited, or "None" if it was just a discussion]
```

## Step 4: Confirm

Tell the user:

```
Saved: [Folder]/[Title].md
```

Keep it short. Just the path so they can find it later.

## Rules

- Date format: YYYY-MM-DD
- Note title format: `TLDR -- [Short Topic Description]` (unless the user overrides)
- If the conversation was trivial (just a greeting, one quick question), say so and ask if they still want to save it
- Don't include sensitive info like API keys or passwords in the summary
