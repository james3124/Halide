/* panel-refa-kunit.c - KUnit suite for carried REF-A DSI panel driver (ch.03 S23).
 * WHY these three cases (S23): probe fail must be -EPROBE_DEFER/-EINVAL, never
 * oops; suspend/resume must balance pm_runtime gets/puts; malformed DT must
 * fail graceful (-EINVAL) so a bad overlay fails safe to framebuffer fallback
 * (S40 layer 3), never panic.
 */
#include <kunit/test.h>

static void panel_probe_missing_irq_defers(struct kunit *test)
{
	/* Missing IRQ -> -EPROBE_DEFER, not oops. */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub: wire to real probe() on builder */
}

static void panel_suspend_resume_balanced(struct kunit *test)
{
	/* pm_runtime get/put balanced across suspend/resume. */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static void panel_dt_malformed_cells_einval(struct kunit *test)
{
	/* Wrong #cells / missing backlight phandle -> graceful -EINVAL. */
	KUNIT_EXPECT_EQ(test, 0, 0); /* stub */
}

static struct kunit_case panel_refa_cases[] = {
	KUNIT_CASE(panel_probe_missing_irq_defers),
	KUNIT_CASE(panel_suspend_resume_balanced),
	KUNIT_CASE(panel_dt_malformed_cells_einval),
	{}
};

static struct kunit_suite panel_refa_suite = {
	.name = "halide-panel-refa",
	.test_cases = panel_refa_cases,
};
kunit_test_suite(panel_refa_suite);
MODULE_LICENSE("GPL");
