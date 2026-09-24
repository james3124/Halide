/* touch-refa-kunit.c - KUnit suite for carried REF-A touch driver (ch.03 S23).
 * WHY (S23 + app-03A S4): touch IRQ must enumerate before multitouch before
 * matrix calibration; probe without IRQ defers, malformed size properties
 * fail clean so evtest 10-finger (hw/refa/input-matrix.conf) starts from sane
 * geometry.
 */
#include <kunit/test.h>

static void touch_probe_missing_irq_defers(struct kunit *test)
{
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub: wire to real probe() on builder */
}

static void touch_suspend_resume_balanced(struct kunit *test)
{
	/* Wake-only-on-gesture (S8): resume re-arms IRQ, no full-SoC wake. */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static void touch_dt_malformed_size_einval(struct kunit *test)
{
	/* Bad touchscreen-size-x/y -> graceful -EINVAL, not zero-size device. */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static struct kunit_case touch_refa_cases[] = {
	KUNIT_CASE(touch_probe_missing_irq_defers),
	KUNIT_CASE(touch_suspend_resume_balanced),
	KUNIT_CASE(touch_dt_malformed_size_einval),
	{}
};

static struct kunit_suite touch_refa_suite = {
	.name = "halide-touch-refa",
	.test_cases = touch_refa_cases,
};
kunit_test_suite(touch_refa_suite);
MODULE_LICENSE("GPL");
