# HALIDE vendor_modules upstreaming
Pristine-tree rule: never patch linux/ in place.
Keep all deltas in halide-base.fragment + sku.fragment.
Upstream-first: send new drivers to mainline before vendoring.
Vendor dir holds only out-of-tree shims with debt entries.
Each shim links a TECH-DEBT.md row and owner.
No binary blobs in tree; firmware via linux-firmware only.
Rebase shims each release; drop when upstream lands.
Owner halide-kernel reviews removals before release cut.
Removal target recorded as rN in TECH-DEBT.md.
