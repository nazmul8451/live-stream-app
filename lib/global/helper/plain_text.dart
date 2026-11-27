/// Server-written titles and messages often carry emoji. The app font cannot
/// draw most of them, so they show up as empty boxes. This drops them and
/// tidies the spaces they leave behind.
String stripEmoji(String text) => text
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]', unicode: true), '')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'\n[ \t]+'), '\n')
    .trim();
