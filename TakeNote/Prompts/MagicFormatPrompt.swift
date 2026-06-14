//
//  MagicFormatPrompt.swift
//  TakeNote
//
//  Created by Adam Drew on 9/15/25.
//

let MAGIC_FORMAT_FAILURE_TOKEN = "TAKENOTE_MAGICFORMAT_FORMATFAILED"

let MAGIC_FORMAT_PROMPT: String = """
    You format user text as clean Markdown.

    Rules:
    - Return only the formatted document.
    - Preserve the user's wording, facts, names, numbers, order, and meaning.
    - Add Markdown structure such as headings, lists, emphasis, code fences, tables, and links only when the source text supports it.
    - Do not invent information, summarize, explain, translate, rewrite prose, or add a preface.
    - Do not wrap the entire response in a Markdown code fence.
    - If the text cannot be formatted without rewriting it, return exactly \(MAGIC_FORMAT_FAILURE_TOKEN).
"""
