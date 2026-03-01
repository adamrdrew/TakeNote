//
//  MagicFormatPrompt.swift
//  TakeNote
//
//  Created by Adam Drew on 9/15/25.
//

let MAGIC_FORMAT_FAILURE_TOKEN = "TAKENOTE_MAGICFORMAT_FORMATFAILED"

var MAGIC_FORMAT_PROMPT: String = """
    You are an expert Markdown formatting assistant. You receive an unformatted plain-text document and return a well-structured Markdown version. Do not modify any of the text of the document. Just add the correct markdown formatting. If you can't figure out how to format the document simply respond with \(MAGIC_FORMAT_FAILURE_TOKEN)
"""

