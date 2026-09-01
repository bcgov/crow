// Ready-to-copy CsCheck generator utility from crow-testing's property-based-testing reference.
// Rename the namespace below to match the target project's test-utilities namespace before use.
using System;
using CsCheck;

namespace YourProject.Tests.Generators
{
    public static class GenDateExtensions
    {
        /// <summary>
        /// Generates a DateTime around today by offsetting days within a range.
        /// Default: +/- 10 years.
        /// </summary>
        public static Gen<DateTime> Date(int minDaysFromToday = -3650, int maxDaysFromToday = 3650)
            => Gen.Int[minDaysFromToday, maxDaysFromToday].Select(offset => DateTime.Today.AddDays(offset));

        /// <summary>
        /// Nullable date generator.
        /// </summary>
        public static Gen<DateTime?> OptDate(int minDaysFromToday = -3650, int maxDaysFromToday = 3650)
            => Gen.OneOf(
                Date(minDaysFromToday, maxDaysFromToday).Select(d => (DateTime?)d),
                Gen.Const((DateTime?)null)
            );

        /// <summary>
        /// Generates a future date (>= Today). Default upper bound: 10 years.
        /// </summary>
        public static Gen<DateTime> FutureDate(int maxDaysFromToday = 3650)
            => Gen.Int[0, maxDaysFromToday].Select(offset => DateTime.Today.AddDays(offset));

        /// <summary>
        /// Generates a past date (< Today). Default lower bound: 10 years.
        /// </summary>
        public static Gen<DateTime> PastDate(int maxDaysBeforeToday = 3650)
            => Gen.Int[-maxDaysBeforeToday, -1].Select(offset => DateTime.Today.AddDays(offset));

        /// <summary>
        /// Generates a TimeOnly anywhere within a day.
        /// </summary>
        public static Gen<TimeOnly> Time()
            => from h in Gen.Int[0, 23]
               from m in Gen.Int[0, 59]
               select new TimeOnly(h, m);

        /// <summary>
        /// Nullable time generator.
        /// </summary>
        public static Gen<TimeOnly?> OptTime()
            => Gen.OneOf(
                Time().Select(t => (TimeOnly?)t),
                Gen.Const((TimeOnly?)null)
            );

        /// <summary>
        /// Same-day period generator. If requireBothTimes is true, both times are non-null.
        /// </summary>
        public static Gen<(DateTime date, TimeOnly? start, TimeOnly? end)> SameDayPeriod(bool requireBothTimes = false)
            => from date in FutureDate()
               from st in requireBothTimes ? Time().Select(t => (TimeOnly?)t) : OptTime()
               from et in requireBothTimes ? Time().Select(t => (TimeOnly?)t) : OptTime()
               select (date, st, et);

        /// <summary>
        /// Multi-day period generator: end date is >= start date + 1..90 days.
        /// </summary>
        public static Gen<(DateTime startDate, TimeOnly? start, DateTime endDate, TimeOnly? end)> MultiDayPeriod()
            => from sd in FutureDate()
               from delta in Gen.Int[1, 90]
               let ed = sd.AddDays(delta)
               from st in OptTime()
               from et in OptTime()
               select (sd, st, ed, et);
    }
}
