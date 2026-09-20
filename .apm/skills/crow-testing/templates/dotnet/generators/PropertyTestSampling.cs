using System;
using CsCheck;

namespace YourProject.Tests.Generators
{
    /// <summary>
    /// Executes CsCheck property-based tests with a deterministic-by-default seed policy, plus an opt-in
    /// switch for exploratory runs. See <see cref="RandomizeEnvironmentVariable"/>.
    /// </summary>
    public static class PropertyTestSampling
    {
        /// <summary>
        /// Environment variable that opts a single test run into CsCheck's broader random seeding instead
        /// of the descriptive seed each property normally supplies. Set it for one run only — for example
        /// <c>$env:CsCheck_Randomize = "true"; dotnet test</c> locally, or as a scheduled/nightly CI job —
        /// rather than leaving it set at machine/CI-agent scope, where it would make every "deterministic"
        /// property test silently non-reproducible. Accepted values are the literal <c>"True"</c>/<c>"False"</c>
        /// (case-insensitive); any other value, or the variable being unset, keeps the deterministic default.
        /// When a run under this switch finds a failure, capture CsCheck's reported reproduction seed,
        /// replay it deterministically, and promote the minimized input to a regression test.
        /// </summary>
        private const string RandomizeEnvironmentVariable = "CsCheck_Randomize";

        /// <summary>
        /// Samples <paramref name="generator"/> and asserts each generated value using the required
        /// <paramref name="seed"/>, so normal runs are deterministic and reproducible. When
        /// <see cref="RandomizeEnvironmentVariable"/> is set to opt into an exploratory run, the supplied
        /// seed is ignored in favor of CsCheck's random seeding for that run (see the one-time console
        /// notice written when the switch is detected). Normal runs invoke each iteration as a separate
        /// single-iteration sample because CsCheck applies its seed only to the first iteration of a
        /// multi-iteration sample.
        /// </summary>
        public static void SampleProperty<T>(
            this Gen<T> generator,
            Action<T> assertion,
            string seed,
            int iter = 100)
        {
            if (ShouldRandomize)
            {
                generator.Sample(assertion, iter: iter);
                return;
            }

            var seedGenerator = PCG.Parse(seed);
            generator.Sample(assertion, iter: 1, seed: seed, threads: 1);

            for (var i = 1; i < iter; i++)
            {
                var iterationSeed = new PCG(seedGenerator.Stream, seedGenerator.Next64()).ToString();
                generator.Sample(assertion, iter: 1, seed: iterationSeed, threads: 1);
            }
        }

        public static void SampleProperty<T1, T2>(
            this Gen<(T1, T2)> generator,
            Action<T1, T2> assertion,
            string seed,
            int iter = 100)
        {
            generator.SampleProperty(value => assertion(value.Item1, value.Item2), seed, iter);
        }

        public static void SampleProperty<T1, T2, T3>(
            this Gen<(T1, T2, T3)> generator,
            Action<T1, T2, T3> assertion,
            string seed,
            int iter = 100)
        {
            generator.SampleProperty(
                value => assertion(value.Item1, value.Item2, value.Item3),
                seed,
                iter);
        }

        public static void SampleProperty<T1, T2, T3, T4>(
            this Gen<(T1, T2, T3, T4)> generator,
            Action<T1, T2, T3, T4> assertion,
            string seed,
            int iter = 100)
        {
            generator.SampleProperty(
                value => assertion(value.Item1, value.Item2, value.Item3, value.Item4),
                seed,
                iter);
        }

        public static void SampleProperty<T1, T2, T3, T4, T5>(
            this Gen<(T1, T2, T3, T4, T5)> generator,
            Action<T1, T2, T3, T4, T5> assertion,
            string seed,
            int iter = 100)
        {
            generator.SampleProperty(
                value => assertion(value.Item1, value.Item2, value.Item3, value.Item4, value.Item5),
                seed,
                iter);
        }

        private static readonly bool ShouldRandomize = DetectRandomize();

        private static bool DetectRandomize()
        {
            var randomize = bool.TryParse(
                Environment.GetEnvironmentVariable(RandomizeEnvironmentVariable),
                out var value) && value;

            if (randomize)
            {
                Console.WriteLine(
                    $"Warning: {RandomizeEnvironmentVariable} is set — this run uses CsCheck's random " +
                    "seeding for every property test; pinned seeds are ignored for this run only.");
            }

            return randomize;
        }
    }
}
