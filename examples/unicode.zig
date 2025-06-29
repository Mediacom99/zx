const std = @import("std");
const fuzzy = @import("fuzzy");
const Chars = fuzzy.Chars;
const unicode = @import("unicode");

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}).init;
    defer _ = dba.deinit();
    const alloc = dba.allocator();

    const raw_input =
        // ASCII start
        "The quick brown fox jumps over the lazy dog! " ++

        // Latin extended
        "Café, naïve, résumé, Zürich, señor, " ++

        // Greek
        "Ελληνικά (Greek): Αλφάβητο, " ++

        // Cyrillic
        "Русский язык (Russian): Привет мир! " ++

        // Chinese
        "中文 (Chinese): 你好世界！春夏秋冬，" ++

        // Japanese (Hiragana, Katakana, Kanji)
        "日本語: ひらがな、カタカナ、漢字、" ++

        // Korean
        "한국어 (Korean): 안녕하세요! " ++

        // Arabic (RTL)
        "العربية: مرحبا بالعالم! " ++

        // Hebrew (RTL)
        "עברית: שלום עולם! " ++

        // Thai
        "ภาษาไทย: สวัสดีครับ " ++

        // Emojis (various byte lengths)
        "Emojis: 😀😃😄😁🤣😂😊😇🙂🙃😉😌 " ++

        // Flags (special emoji sequences)
        "Flags: 🇺🇸🇬🇧🇯🇵🇩🇪🇫🇷🇰🇷 " ++

        // Complex emojis (with modifiers)
        "Complex: 👨‍👩‍👧‍👦👨‍💻👩‍🔬🧑‍🚀 " ++

        // Mathematical symbols
        "Math: ∑∏∫∂∇∆√∞≈≠≤≥±∓×÷ " ++

        // Currency symbols
        "Currency: $€£¥₹₽₩₪ " ++

        // Box drawing
        "Box: ┌─┬─┐│ │ ││ │ │└─┴─┘ " ++

        // Arrows
        "Arrows: ←↑→↓↔↕⇐⇒⇔⇕ " ++

        // Musical symbols
        "Music: ♩♪♫♬♭♮♯ " ++

        // Miscellaneous symbols
        "Misc: ©®™℗№℮¶§†‡※‼⁇ " ++

        // Combining characters
        "Combining: a\u{0301}e\u{0301}i\u{0301}o\u{0301}u\u{0301} " ++ // áéíóú using combining acute

        // Zero-width characters
        "Zero-width: a\u{200B}b\u{200C}c\u{200D}d " ++ // Various zero-width chars

        // Replacement character
        "Replacement: \u{FFFD} " ++

        // Various quote marks
        "Quotes: \"Hello\" 'World' «Bonjour» „Guten Tag\"" ++

        // Ligatures
        "Ligatures: ﬁ ﬂ ﬀ ﬃ ﬄ " ++

        // Superscript/Subscript
        "Super/Sub: x² y³ H₂O CO₂ " ++

        // Fractions
        "Fractions: ½ ⅓ ¼ ⅕ ⅙ ⅐ ⅛ ⅑ ⅒ " ++

        // Roman numerals
        "Roman: Ⅰ Ⅱ Ⅲ Ⅳ Ⅴ Ⅵ Ⅶ Ⅷ Ⅸ Ⅹ " ++
        "♍ ⡆⨕ﺥ𐀉" ++

        // End with ASCII
        "END OF TEST STRING!";

    const input = try unicode.sanitizeUtf8UnmanagedStd(alloc, raw_input);
    defer alloc.free(input);

    std.debug.print("=== Testing complex UTF-8 ===\n", .{});
    std.debug.print("Input: \"{s}\"\n", .{input});
    std.debug.print("Input length in bytes: {}\n\n", .{input.len});

    // Now decode
    var chars = try Chars.initFromByteSlice(alloc, input);
    defer chars.deinit(alloc);

    std.debug.print("--- Decoding Results ---\n", .{});
    std.debug.print("is_ascii: {}\n", .{chars.is_ascii});
    std.debug.print("length in runes: {}\n", .{chars.length()});

    // Examine each codepoint
    const codepoints = chars.toCodepoints() orelse unreachable;
    std.debug.print("\nCodepoint analysis ({} codepoints):\n", .{codepoints.len});

    var unicode_string = std.ArrayList(u8).init(alloc);
    defer unicode_string.deinit();
    for (codepoints, 0..) |cp, i| {
        unicode_string.clearRetainingCapacity();
        std.debug.print("  [{:2}] U+{X:0>4} (dec: {:6}) ", .{ i, cp, cp });
        try std.fmt.formatUnicodeCodepoint(@intCast(cp), .{}, unicode_string.writer());
        std.debug.print("Rune: {s}", .{unicode_string.items});

        // Describe the character
        const desc: []const u8 = switch (cp) {
            0x0000...0x007F => " - " ++ "ascii",
            0xFFFD => " - " ++ "replacement",
            else => "",
        };
        std.debug.print("{s}\n", .{desc});
    }
}
