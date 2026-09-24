# sensor power attribution (ch04 s32) - refa TEMPLATE
# Meter cal ID (ch10 s8): TODO-measured. Bench: sacrificial, airplane, screen-off.
# sensor,nonbatch_50Hz_1h_mA,maxbatch_1h_mA,win_pct,fifo_worth_it,note
accel,TODO,TODO,TODO,TODO batch-on vs batch-off 1h static-on-table
gyro,TODO,TODO,TODO,TODO win must be >=30% or file FIFO-NOT-WORTH-IT
mag,TODO,TODO,TODO,TODO,
baro,TODO,TODO,TODO,TODO 1Hz dogfood profile
als,TODO,on-change,TODO,TODO,
prox,TODO,on-change,TODO,TODO,
# Overnight dogfood (accel+gyro batch-max + ALS/prox on-change + baro 1Hz):
# TODO-measured drain <=3%/8h REF-A target. Baseline sensors-off 8h deep >=95%.
# Correctness: shake-table 100Hz 60s dropped-batch 0; wakeup_sources named wakes;
# HW timestamp jitter <2ms vs CLOCK_BOOTTIME (histogram per release).
# Status: UNMEASURED.
