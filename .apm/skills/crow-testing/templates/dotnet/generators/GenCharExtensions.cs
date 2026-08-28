// Ready-to-copy CsCheck generator utility from crow-testing's property-based-testing reference.
// Rename the namespace below to match the target project's test-utilities namespace before use.
using CsCheck;

namespace YourProject.Tests.Generators
{
    /// <summary>
    /// Efficient character generators for property-based testing.
    /// Optimized for "Smart" coverage: biases towards common input while ensuring
    /// statistical significance of known edge cases (Turkish I, Homoglyphs, RTL).
    /// </summary>
    public static class GenCharExtensions
    {
        // --- Static Data Caches (Prevent Allocations) ---

        // Homoglyphs: Characters that look like ASCII but aren't (Security/Spoofing)
        // Includes Cyrillic/Greek variants of a, c, e, o, p, x, y
        private static readonly char[] _homoglyphs =
        {
            'а', 'с', 'е', 'о', 'р', 'х', 'у', 'і', // Cyrillic
            'ο', 'ρ', 'ν', 'χ'                      // Greek
        };

        // Normalization & Case Folding Hazards
        // Turkish I, German Eszett, Ligatures
        private static readonly char[] _normalizationHazards =
        {
            'ı', 'İ',           // Turkish I (dotless i, dotted I)
            'ß', 'ẞ',           // German Eszett (changes length on ToUpper)
            'ﬁ', 'ﬂ', 'æ', 'œ', // Ligatures (may decompose)
            'K',                // Kelvin Sign (normalizes to K)
            'Å'                 // Angstrom (normalizes to A with ring)
        };

        // Right-to-Left (RTL) samples for Bidi testing
        private static readonly char[] _rtlChars =
        {
            'א', 'ב', 'ג', 'ד', // Hebrew
            'ا', 'ب', 'ت', 'ث'  // Arabic
        };

        // CJK & Fullwidth (Wide characters)
        private static readonly char[] _wideChars =
        {
            '李', '王', '張', // Chinese
            'あ', 'い', 'う', // Japanese Hiragana
            'Ａ', 'Ｂ', 'Ｃ'  // Fullwidth Latin (looks like ASCII, isn't)
        };

        // Whitespace including invisible formatting chars
        private static readonly char[] _smartWhitespace =
        {
            ' ',      // U+0020 - Space
            '\t',     // U+0009 - Tab
            '\n',     // U+000A - Line Feed
            '\r',     // U+000D - Carriage Return
            '\v',     // U+000B - Vertical Tab
            '\f',     // U+000C - Form Feed
            '\u00A0', // U+00A0 - Non-Breaking Space
            '\u1680', // U+1680 - Ogham Space Mark
            '\u2000', // U+2000 - En Quad
            '\u2001', // U+2001 - Em Quad
            '\u2002', // U+2002 - En Space
            '\u2003', // U+2003 - Em Space
            '\u2004', // U+2004 - Three-Per-Em Space
            '\u2005', // U+2005 - Four-Per-Em Space
            '\u2006', // U+2006 - Six-Per-Em Space
            '\u2007', // U+2007 - Figure Space
            '\u2008', // U+2008 - Punctuation Space
            '\u2009', // U+2009 - Thin Space
            '\u200A', // U+200A - Hair Space
            '\u2028', // U+2028 - Line Separator
            '\u2029', // U+2029 - Paragraph Separator
            '\u202F', // U+202F - Narrow No-Break Space
            '\u205F', // U+205F - Medium Mathematical Space
            '\u3000', // U+3000 - Ideographic Space
        };


        // --- Generators ---

        /// <summary>
        /// Standard ASCII Letters (a-z, A-Z).
        /// </summary>
        public static Gen<char> AsciiLetter()
        {
            return Gen.OneOf(Gen.Char['a', 'z'], Gen.Char['A', 'Z']);
        }

        /// <summary>
        /// A "Smart" Unicode generator.
        /// Biased frequency:
        /// 50% ASCII (Happy path),
        /// 25% Common Latin1 (Accents),
        /// 25% Edge Cases (Homoglyphs, RTL, Turkish I, Normalization hazards).
        /// </summary>
        public static Gen<char> UnicodeLetter()
        {
            return Gen.Frequency(
                // Most user input is ASCII, keep this high frequency
                (50, AsciiLetter()),

                // Common European inputs (Latin-1 Supplement block)
                (25, Gen.Char['\u00C0', '\u00FF']),

                // The "Nasty" Stuff - specifically targeted edge cases
                (5, Gen.OneOfConst(_homoglyphs)),
                (5, Gen.OneOfConst(_normalizationHazards)),
                (5, Gen.OneOfConst(_rtlChars)),
                (5, Gen.OneOfConst(_wideChars)),

                // General coverage of Greek/Cyrillic blocks for good measure
                (5, Gen.Char['\u0370', '\u04FF'])
            );
        }

        public static Gen<char> AsciiDigits()
        {
            return Gen.Char['0', '9'];
        }

        public static Gen<char> NonAsciiDigits()
        {
            // These are distinct from ASCII but are considered digits by char.IsDigit()
            var fullwidthDigits = Gen.Char['\uFF10', '\uFF19'];

            // Other common digits, e.g., Arabic-Indic (U+0660 to U+0669)
            var arabicIndicDigits = Gen.Char['\u0660', '\u0669'];

            // Randomly select from the efficient generators
            return Gen.OneOf(fullwidthDigits, arabicIndicDigits);
        }

        /// <summary>
        /// Generates digits, including standard ASCII and tricky non-ASCII digits.
        /// </summary>
        public static Gen<char> UnicodeDigit()
        {
            var ascii = AsciiDigits();
            var nonAscii = NonAsciiDigits();

            // 80% ASCII, 20% Edge cases
            return Gen.Frequency(
                (8, ascii),
                (2, nonAscii)
            );
        }

        /// <summary>
        /// Generates whitespace, including dangerous invisible characters (ZWJ, ZWNJ, BOM).
        /// </summary>
        public static Gen<char> UnicodeWhitespace()
        {
            return Gen.OneOfConst(_smartWhitespace);
        }

        /// <summary>
        /// Generates non-whitespace
        /// </summary>
        public static Gen<char> NonWhitespace()
        {
            return Gen.Frequency(
                (10, AsciiLetter()),
                (5, AsciiDigits())
            );
        }

        /// <summary>
        /// Letters or Space. Good for testing names/titles.
        /// </summary>
        public static Gen<char> LetterOrSpace(bool asciiLettersOnly = true)
        {
            var letters = asciiLettersOnly ? AsciiLetter() : UnicodeLetter();
            return Gen.Frequency(
                (9, letters),
                (1, UnicodeWhitespace()) // 10% chance of whitespace
            );
        }

        /// <summary>
        /// Letters, Digits, or Space. Alphanumeric testing.
        /// </summary>
        public static Gen<char> LetterDigitOrSpace(bool asciiLettersOnly = true)
        {
            return Gen.Frequency(
                (10, asciiLettersOnly ? AsciiLetter() : UnicodeLetter()),
                (5, UnicodeDigit()),
                (1, UnicodeWhitespace())
            );
        }

        /// <summary>
        /// Human-friendly subset.
        /// Excludes the nasty invisible chars and confusing homoglyphs.
        /// Useful for "Strict" input fields.
        /// </summary>
        public static Gen<char> HumanFriendlyLetterOrSpace()
        {
            // Simple space, no ZWJ/ZWNJ
            var basicSpace = Gen.Const(' ');

            return Gen.Frequency(
                (10, AsciiLetter()),
                (5, Gen.Char['\u00C0', '\u00FF']), // Latin-1 Accents
                (2, basicSpace)
            );
        }
    }
}
