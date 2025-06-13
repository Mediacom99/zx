# Unicode

1. Check all input and replace invalid unicode codepoints (u21) with replacement char (0xFFFD)
2. Make sure to read and write unicode codepoints, not just bytes (std.unicode.utf8View)
3. For now we support utf8 only. In the future we could support utf16 or use wtf8 for round-tripping utf16 (Windows, Javascript, Java..)
