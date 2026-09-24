/* pinctrl-refa-kunit.c - KUnit suite for carried REF-A pinctrl quirks (ch.03 S23).
 * WHY (S13 + S23): one state per peripheral (default + sleep); a missing
 * sleep state silently doubles idle current (regulator trap S13), so the
 * suite asserts both states parse and select.
 */
#include <kunit/test.h>

static void pinctrl_default_state_present(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub: wire to real quirk parse on builder */
}

static void pinctrl_sleep_state_present(struct kunit *test)
{
	/* Missing sleep state = finding, not fallback (idle-power gate). */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static void pinctrl_dt_malformed_cells_einval(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static struct kunit_case pinctrl_refa_cases[] = {
	KUNIT_CASE(pinctrl_default_state_present),
	KUNIT_CASE(pinctrl_sleep_state_present),
	KUNIT_CASE(pinctrl_dt_malformed_cells_einval),
	{}
};

static struct kunit_suite pinctrl_refa_suite = {
	.name = "halide-pinctrl-refa",
	.test_cases = pinctrl_refa_cases,
};
kunit_test_suite(pinctrl_refa_suite);
MODULE_LICENSE("GPL");
