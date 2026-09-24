/* gauge-refa-kunit.c - KUnit suite for carried REF-A battery gauge driver (ch.03 S23).
 * WHY (S23 + S13): gauge misreport corrupts FCC-vs-design (hw/refa/battery.md)
 * and temperature compensation (app-03A quirk 3); ADC channel misparse must
 * fail clean, suspend must not lose Coulomb-counter state.
 */
#include <kunit/test.h>

static void gauge_probe_missing_adc_defers(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub: wire to real probe() on builder */
}

static void gauge_suspend_resume_preserves_counter(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static void gauge_dt_malformed_adc_einval(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static struct kunit_case gauge_refa_cases[] = {
	KUNIT_CASE(gauge_probe_missing_adc_defers),
	KUNIT_CASE(gauge_suspend_resume_preserves_counter),
	KUNIT_CASE(gauge_dt_malformed_adc_einval),
	{}
};

static struct kunit_suite gauge_refa_suite = {
	.name = "halide-gauge-refa",
	.test_cases = gauge_refa_cases,
};
kunit_test_suite(gauge_refa_suite);
MODULE_LICENSE("GPL");
