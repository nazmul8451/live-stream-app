/// Server-written titles and messages often carry emoji. The app font cannot
/// draw most of them, so they show up as empty boxes. This drops them and
/// tidies the spaces they leave behind.
String stripEmoji(String text) => text
    .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}\u{20E3}]', unicode: true), '')
    .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
    .replaceAll(RegExp(r'\n[ \t]+'), '\n')
    .trim();
