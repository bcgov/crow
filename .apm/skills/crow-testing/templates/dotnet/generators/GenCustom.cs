// Ready-to-copy CsCheck generator utility from crow-testing's property-based-testing reference.
// Rename the namespace below to match the target project's test-utilities namespace before use.
using System;
using System.Linq;
using CsCheck;

namespace YourProject.Tests.Generators
{
    public static class GenCustom
    {
        public static Gen<(int d1, int d2, int d3, int d4, int d5)> GenPhoneNumberDigits() =>
            Gen.Select(
                Gen.Int[0, 9], // d1
                Gen.Int[0, 9], // d2
                Gen.Int[0, 9], // d3
                Gen.Int[0, 9], // d4
                Gen.Int[0, 9]  // d5
            );

        // Custom Generator that produces the formatted phone number string directly
        public static Gen<string> GenValidPhoneNumber()
        {
            var baseDigitsGen = GenPhoneNumberDigits();

            // Format 1: With a space after the area code closing parenthesis
            var genFormat1 = baseDigitsGen.Select(digits =>
            {
                var (d1, d2, d3, d4, d5) = digits;
                return $"({d1}{d2}{d3}) {d4}{d5}{d1}-{d2}{d3}{d4}{d5}";
            });

            // Format 2: Without a space after the area code closing parenthesis
            var genFormat2 = baseDigitsGen.Select(digits =>
            {
                var (d1, d2, d3, d4, d5) = digits;
                return $"({d1}{d2}{d3}){d4}{d5}{d1}-{d2}{d3}{d4}{d5}";
            });

            return Gen.OneOf(genFormat1, genFormat2);
        }

        private static Gen<string> GenNDigits(int n) => Gen.String[GenCharExtensions.AsciiDigits(), n, n];

        // Generator for the three core phone number components
        public static Gen<(string areaCode, string prefix, string suffix)> GenPhoneNumberComponents() =>
            Gen.Select(
                GenNDigits(3), // Area Code (3 digits)
                GenNDigits(3), // Prefix (3 digits)
                GenNDigits(4)  // Suffix (4 digits)
            );

        /// <summary>
        /// Generates strings without leading or trailing whitespace.
        /// Ensures first and last characters are non-whitespace.
        /// </summary>
        public static Gen<string> GenStringTrimmed(Gen<char> charGen, int minLength, int maxLength)
        {

            if (minLength < 1)
            {
                throw new ArgumentException("minLength must be at least 1", nameof(minLength));
            }

#if DEBUG
            // Validate that generator can produce non-whitespace
            bool hasNonWhitespace = false;
            charGen.Array[10].Sample(arr => hasNonWhitespace = arr.Any(c => !char.IsWhiteSpace(c)), iter: 1);

            System.Diagnostics.Debug.Assert(
                hasNonWhitespace,
                "StringNoTrim requires a generator capable of producing non-whitespace characters. " +
                "The provided generator appears to only produce whitespace.");
#endif

            var nonWhitespaceGen = charGen.Where(c => !char.IsWhiteSpace(c));

            return Gen.Int[minLength, maxLength].SelectMany(length =>
            {
                if (length == 1)
                {
                    // Single char - must not be whitespace
                    return nonWhitespaceGen.Select(c => c.ToString());
                }

                // First char (non-whitespace)
                var first = nonWhitespaceGen;

                // Middle chars (can be anything including whitespace)
                var middle = length > 2
                    ? Gen.String[charGen, length - 2, length - 2]
                    : Gen.Const(string.Empty);

                // Last char (non-whitespace)
                var last = nonWhitespaceGen;

                return Gen.Select(first, middle, last, (f, m, l) => $"{f}{m}{l}");
            });
        }
    }
}
