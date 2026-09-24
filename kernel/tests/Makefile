# Makefile for kernel/tests KUnit suites (ch.03 S23).
# WHY obj-$(CONFIG_...) (S23): suites build and run in the same tree/config
# as the S11 build; CI invokes tools/testing/kunit/kunit.py run --arch=arm64.

obj-$(CONFIG_HALIDE_KUNIT_PANEL_REFA) += panel-refa-kunit.o
obj-$(CONFIG_HALIDE_KUNIT_TOUCH_REFA) += touch-refa-kunit.o
obj-$(CONFIG_HALIDE_KUNIT_GAUGE_REFA) += gauge-refa-kunit.o
obj-$(CONFIG_HALIDE_KUNIT_PINCTRL_REFA) += pinctrl-refa-kunit.o
