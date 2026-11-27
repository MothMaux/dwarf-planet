VIVADO_VERSION ?= 2025.1

BUILDROOT_DIR = $(CURDIR)/buildroot

# Cross-compiler provided by buildroot toolchain
CROSS_COMPILE = arm-linux-gnueabihf-
TOOLS_PATH = PATH="$(BUILDROOT_DIR)/output/host/bin:$(BUILDROOT_DIR)/output/host/sbin:$(PATH)"
TOOLCHAIN = $(BUILDROOT_DIR)/output/host/bin/$(CROSS_COMPILE)gcc

NCORES = $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
VIVADO_SETTINGS ?= /tools/Xilinx/$(VIVADO_VERSION)/Vivado/settings64.sh

VSUBDIRS = hdl linux u-boot

VERSION:=$(shell git describe --abbrev=4 --dirty --always --tags)
UBOOT_VERSION=$(shell echo -n "PlutoSDR " && cd u-boot && git describe --abbrev=0 --dirty --always --tags)
HAVE_VIVADO= $(shell bash -c "source $(VIVADO_SETTINGS) > /dev/null 2>&1 && vivado -version > /dev/null 2>&1 && echo 1 || echo 0")

ifeq (1, ${HAVE_VIVADO})
	VIVADO_INSTALL= $(shell bash -c "source $(VIVADO_SETTINGS) > /dev/null 2>&1 && vivado -version | head -1 | awk '{print $$2}'")
	ifeq (, $(findstring $(VIVADO_VERSION), $(VIVADO_INSTALL)))
$(warning *** This repository has only been tested with $(VIVADO_VERSION),)
$(warning *** and you have $(VIVADO_INSTALL))
$(warning *** Please 1] set the path to Vivado $(VIVADO_VERSION) OR)
$(warning ***        2] remove $(VIVADO_INSTALL) from the path OR)
$(error "      3] export VIVADO_VERSION=v20xx.x")
	endif
endif

TARGET ?= pluto
SUPPORTED_TARGETS:=pluto libre nano e200 fishball7010 fishball7020

# Include target specific constants
-include scripts/$(TARGET).mk

ifeq (, $(shell which dfu-suffix))
$(warning "No dfu-utils in PATH consider doing: sudo apt-get install dfu-util")
TARGETS = build/$(TARGET).frm
ifeq (1, ${HAVE_VIVADO})
TARGETS += build/boot.frm jtag-bootstrap
endif
else
TARGETS = build/$(TARGET).dfu build/uboot-env.dfu build/$(TARGET).frm
ifeq (1, ${HAVE_VIVADO})
TARGETS += build/boot.dfu build/boot.frm jtag-bootstrap
endif
endif

ifeq ($(findstring $(TARGET),$(SUPPORTED_TARGETS)),)
all:
	@echo "Invalid TARGET variable ; valid values are: $(SUPPORTED_TARGETS)" && exit 1
else
all: clean-build $(TARGETS) zip-all legal-info
endif

.NOTPARALLEL: all

.PHONY: all clean clean-build zip-all legal-info sysroot jtag-bootstrap
.PHONY: dfu-$(TARGET) dfu-sf-uboot dfu-all dfu-ram uboot-test-ram
.PHONY: git-update-all git-pull

TARGET_DTS_FILES:=$(foreach dts,$(TARGET_DTS_FILES),build/$(dts))

TOOLCHAIN:
	$(MAKE) -C $(BUILDROOT_DIR) ARCH=arm zynq_$(TARGET)_defconfig
	$(MAKE) -C $(BUILDROOT_DIR) toolchain

build:
	mkdir -p $@

%: build/%
	cp $< $@


### u-boot ###

u-boot/u-boot u-boot/tools/mkimage: TOOLCHAIN
	$(TOOLS_PATH) $(MAKE) -C u-boot ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_defconfig
	$(TOOLS_PATH) $(MAKE) -C u-boot -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)

.PHONY: u-boot/u-boot

build/u-boot.elf: u-boot/u-boot | build
	cp $< $@

build/uboot-env.txt: u-boot/u-boot TOOLCHAIN | build
	$(TOOLS_PATH) CROSS_COMPILE=$(CROSS_COMPILE) scripts/get_default_envs.sh > $@

build/uboot-env.bin: build/uboot-env.txt
	u-boot/tools/mkenvimage -s 0x20000 -o $@ $<

### Linux ###

linux/arch/arm/boot/zImage: TOOLCHAIN
	$(TOOLS_PATH) $(MAKE) -C linux ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_defconfig
	$(TOOLS_PATH) $(MAKE) -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zImage UIMAGE_LOADADDR=0x8000
	$(TOOLS_PATH) $(MAKE) -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) uImage UIMAGE_LOADADDR=0x8000


.PHONY: linux/arch/arm/boot/zImage


build/zImage: linux/arch/arm/boot/zImage | build
	cp $< $@

### Device Tree ###

linux/arch/arm/boot/dts/%.dtb: TOOLCHAIN linux/arch/arm/boot/dts/%.dts linux/arch/arm/boot/dts/zynq-pluto-sdr.dtsi
	$(TOOLS_PATH) DTC_FLAGS=-@ $(MAKE) -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) $(notdir $@)

build/%.dtb: linux/arch/arm/boot/dts/%.dtb | build
	dtc -q -@ -I dtb -O dts $< | sed 's/axi {/amba {/g' | dtc -q -@ -I dts -O dtb -o $@

### Buildroot ###

$(BUILDROOT_DIR)/output/images/rootfs.cpio.gz:
	@echo device-fw $(VERSION)> $(BUILDROOT_DIR)/board/$(TARGET)/VERSIONS
	@$(foreach dir,$(VSUBDIRS),echo $(dir) $(shell cd $(dir) && git describe --abbrev=4 --dirty --always --tags) >> $(BUILDROOT_DIR)/board/$(TARGET)/VERSIONS;)
	@echo buildroot $(shell cd $(BUILDROOT_DIR) && git describe --abbrev=4 --dirty --always --tags 2>/dev/null || echo unknown) >> $(BUILDROOT_DIR)/board/$(TARGET)/VERSIONS
	$(MAKE) -C $(BUILDROOT_DIR) ARCH=arm zynq_$(TARGET)_defconfig

	$(MAKE) -C $(BUILDROOT_DIR) BUSYBOX_CONFIG_FILE=$(BUILDROOT_DIR)/board/$(TARGET)/busybox-1.25.0.config all

.PHONY: $(BUILDROOT_DIR)/output/images/rootfs.cpio.gz

build/rootfs.cpio.gz: $(BUILDROOT_DIR)/output/images/rootfs.cpio.gz | build
	cp $< $@

build/$(TARGET).itb: u-boot/tools/mkimage build/zImage build/rootfs.cpio.gz $(TARGET_DTS_FILES) build/system_top.bit
	u-boot/tools/mkimage -f scripts/$(TARGET).its $@

build/system_top.xsa:  | build
ifeq (1, ${HAVE_VIVADO})
	bash -c "source $(VIVADO_SETTINGS)"
	env -u TARGET -u MAKEFLAGS $(MAKE) -C hdl/projects/$(TARGET)
	bash -c "cp hdl/projects/$(TARGET)/$(TARGET).sdk/system_top.xsa $@"
	unzip -l $@ | grep -q ps7_init || cp hdl/projects/$(TARGET)/$(TARGET).srcs/sources_1/bd/system/ip/system_sys_ps7_0/ps7_init* build/
else ifneq ($(XSA_FILE),)
	cp $(XSA_FILE) $@
else ifneq ($(XSA_URL),)
	wget -T 3 -t 1 -N --directory-prefix build $(XSA_URL)
endif

### TODO: Build system_top.xsa from src if dl fails ...

build/sdk/fsbl/Release/fsbl.elf build/system_top.bit : build/system_top.xsa
	rm -Rf build/sdk
ifeq (1, ${HAVE_VIVADO})
	bash -c "source $(VIVADO_SETTINGS) && xsct scripts/create_fsbl_project.tcl"
else
	unzip -o build/system_top.xsa system_top.bit -d build
endif

build/boot.bin: build/sdk/fsbl/Release/fsbl.elf build/u-boot.elf
	@echo img:{[bootloader] $^ } > build/boot.bif
	bash -c "source $(VIVADO_SETTINGS) && bootgen -image build/boot.bif -w -o $@"

### MSD update firmware file ###

build/$(TARGET).frm: build/$(TARGET).itb
	md5sum $< | cut -d ' ' -f 1 > $@.md5
	cat $< $@.md5 > $@

build/boot.frm: build/boot.bin build/uboot-env.bin scripts/target_mtd_info.key
	cat $^ | tee $@ | md5sum | cut -d ' ' -f1 | tee -a $@

### DFU update firmware file ###

define dfu-suffix-recipe
	cp $< $<.tmp
	dfu-suffix -a $<.tmp -v $(DEVICE_VID) -p $(DEVICE_PID)
	mv $<.tmp $@
endef

build/%.dfu: build/%.bin
	$(dfu-suffix-recipe)

build/$(TARGET).dfu: build/$(TARGET).itb
	$(dfu-suffix-recipe)

clean-build:
	rm -f $(notdir $(wildcard build/*))
	rm -rf build/*
	rm -rf build_sdimg

clean:
	$(MAKE) -C u-boot clean
	$(MAKE) -C linux clean
	$(MAKE) -C $(BUILDROOT_DIR) clean
	$(MAKE) -C hdl clean
	rm -f $(notdir $(wildcard build/*))
	rm -rf build/*
	rm -rf build_sdimg

overclock: build/sdk/fsbl/Release/fsbl.elf
	test -n "$(OVERCLOCK_CPU_MULT)"  # Check environment veriable OVERCLOCK_CPU_MULT for overclock.
	test -n "$(OVERCLOCK_DDR_MULT)"  # Check environment veriable OVERCLOCK_DDR_MULT for overclock.
	bash -c "source $(VIVADO_SETTINGS) && ./overclock.sh $(OVERCLOCK_CPU_MULT) $(OVERCLOCK_DDR_MULT)"

SDIMGDIR = $(CURDIR)/build_sdimg
sdimg: build/
	rm -rf $(SDIMGDIR)
	mkdir $(SDIMGDIR)
	cp build/sdk/fsbl/Release/fsbl.elf 	$(SDIMGDIR)/fsbl.elf  
	cp build/sdk/system_top/hw/system_top.bit 	$(SDIMGDIR)/system_top.bit
	cp build/u-boot.elf 			$(SDIMGDIR)/u-boot.elf
	cp $(CURDIR)/linux/arch/arm/boot/uImage	$(SDIMGDIR)/uImage
	cp build/zynq-$(TARGET).dtb 	$(SDIMGDIR)/devicetree.dtb
	cp build/uboot-env.txt  		$(SDIMGDIR)/uEnv.txt
	cp build/rootfs.cpio.gz  		$(SDIMGDIR)/ramdisk.image.gz
	mkimage -A arm -T ramdisk -C gzip -d $(SDIMGDIR)/ramdisk.image.gz $(SDIMGDIR)/uramdisk.image.gz
	touch 	$(SDIMGDIR)/boot.bif
	echo "img : {[bootloader] $(SDIMGDIR)/fsbl.elf  $(SDIMGDIR)/system_top.bit  $(SDIMGDIR)/u-boot.elf}" >  $(SDIMGDIR)/boot.bif
	bash -c "source $(VIVADO_SETTINGS) && bootgen -image $(SDIMGDIR)/boot.bif -o i $(SDIMGDIR)/BOOT.bin"
	rm $(SDIMGDIR)/fsbl.elf
	rm $(SDIMGDIR)/system_top.bit
	rm $(SDIMGDIR)/u-boot.elf
	rm $(SDIMGDIR)/ramdisk.image.gz 
	rm $(SDIMGDIR)/boot.bif

OC_BIN        = build_sdimg/overclocks/FSBL_$(CPU)_$(MEM)
CPU_PRE := EMIT_MASKWRITE\(0XF8000100, 0x0007F000U ,0x000
MEM_PRE := EMIT_MASKWRITE\(0XF8000104, 0x0007F000U ,0x000
MW_POST := 000U\),

define DIFF_PY
import re, sys

base_path, new_path, cpu_s, mem_s, out_path = sys.argv[1:6]
cpu, mem = int(cpu_s, 10), int(mem_s, 10)

MASK = 0x0007F000
REGS = (("CPU", 0xF8000100, cpu), ("MEM", 0xF8000104, mem))

def die(msg):
    sys.exit("DIFF CHECK FAILED: " + msg)

def entries(data, addr):
    # ps7_init table entry = {opcode, addr, mask, val}, 32-bit little-endian words.
    # Match addr+mask, capture val; return (offset_of_val, val).
    key = re.escape(addr.to_bytes(4, "little") + MASK.to_bytes(4, "little"))
    return [(m.start(1), int.from_bytes(m.group(1), "little"))
            for m in re.finditer(key + b"(.{4})", data, re.S)]

base = open(base_path, "rb").read()
new = open(new_path, "rb").read()
if len(base) != len(new):
    die("size differs: %s=%d bytes, %s=%d bytes" % (base_path, len(base), new_path, len(new)))

# byte-level diff
diffs = []
CH = 1 << 16
for off in range(0, len(base), CH):
    a, b = base[off:off + CH], new[off:off + CH]
    if a != b:
        diffs += [off + i for i in range(len(a)) if a[i] != b[i]]
if not diffs:
    die("files are identical (did the build step overwrite BOOT.bin, or skip the rebuild?)")

allowed, rows = set(), []
for name, addr, mult in REGS:
    old_e, new_e = entries(base, addr), entries(new, addr)
    if len(old_e) != 3 or len(new_e) != 3:
        die("%s (0x%08X): expected 3 table entries, found %d in base / %d in new"
            % (name, addr, len(old_e), len(new_e)))
    for n, ((bo, bv), (no, nv)) in enumerate(zip(old_e, new_e), 1):
        if bo != no:
            die("%s[%d] moved: base 0x%X vs new 0x%X" % (name, n, bo, no))
        if nv != (mult << 12):
            die("%s[%d] @0x%X: value is 0x%08X, expected 0x%08X (multiplier %d)"
                % (name, n, no, nv, mult << 12, mult))
        allowed.update(range(bo, bo + 4))
        rows.append((name, n, bo, (bv >> 12) & 0x7F, mult))

stray = [d for d in diffs if d not in allowed]
if stray:
    die("%d differing byte(s) outside the 6 PLL words, first at: %s"
        % (len(stray), ", ".join(hex(d) for d in stray[:8])))

for name, n, off, old, mult in rows:
    note = "" if old != mult else "  (multiplier unchanged)"
    print("  %s[%d] @ 0x%08X: %d -> %d%s" % (name, n, off, old, mult, note))
print("Diff OK: %d differing byte(s), all inside the 6 expected PLL words." % len(diffs))

with open(out_path, "w") as f:
    f.write("# This file is auto-generated by 'make sdimg_oc' do not edit.\n")
    for name, n, off, old, mult in rows:
        f.write("%s_%d=0x%08X\n" % (name, n, off))
print("Wrote " + out_path)
endef
export DIFF_PY

sdimg_oc: SHELL := /bin/bash
.PHONY: sdimg_oc
sdimg_oc:
	@[ -d "build_sdimg" ] || { echo "Error: build_sdimg/ does not exist (run 'make sdimg' first)"; exit 1; }
	@[ -f "build_sdimg/BOOT.bin" ] || { echo "Error: build_sdimg/BOOT.bin not found (run 'make sdimg' first)"; exit 1; }
	@set -e; for kv in CPU=$(CPU) MEM=$(MEM); do \
	  name=$${kv%%=*}; val=$${kv#*=}; \
	  if ! [[ "$$val" =~ ^[0-9]+$$ ]] || [ "$$((10#$$val))" -lt 1 ] || [ "$$((10#$$val))" -gt 127 ]; then \
	    echo "Error: $$name multiplier '$$val' is invalid. Must be an integer >0 and <128."; \
	    echo "Usage: make sdimg_oc CPU=40 MEM=28"; \
	    exit 3; \
	  fi; \
	done
	@[ -f "build/sdk/fsbl/src/ps7_init.c" ] || { echo "Error: build/sdk/fsbl/src/ps7_init.c not found! (make build/sdk/fsbl/Release/fsbl.elf first)"; exit 2; }
	@set -e; for kind in CPU MEM; do \
	  if [ "$$kind" = CPU ]; then pre='$(CPU_PRE)'; new='$(CPU)'; else pre='$(MEM_PRE)'; new='$(MEM)'; fi; \
	  new=$$((10#$$new)); \
	  hits=$$(grep -cE "$$pre..$(MW_POST)" "build/sdk/fsbl/src/ps7_init.c" || true); \
	  if [ "$$hits" -lt 1 ]; then echo "Error: no $$kind PLL EMIT_MASKWRITE line found in build/sdk/fsbl/src/ps7_init.c"; exit 5; fi; \
	  [ "$$hits" -eq 3 ] || echo "Warning: expected 3 $$kind entries in ps7_init.c, found $$hits"; \
	  cur_hex=$$(sed -rn "s/.*$$pre(..)$(MW_POST).*/\1/p" "build/sdk/fsbl/src/ps7_init.c" | sed -n 1p); \
	  echo "Current $$kind multiplier: $$((16#$$cur_hex)), new multiplier: $$new"; \
	  new_hex=$$(printf '%02X' "$$new"); \
	  sed -i -r "s/($$pre)..($(MW_POST))/\1$$new_hex\2/" "build/sdk/fsbl/src/ps7_init.c"; \
	done
	bash -c "source $(VIVADO_SETTINGS) && env -u MAKEFLAGS -u CPU -u MEM make -C build/sdk/fsbl/Release clean && env -u MAKEFLAGS -u CPU -u MEM make -C build/sdk/fsbl/Release"
	mkdir -p build_sdimg/overclocks
	echo "img : {[bootloader] $(CURDIR)/build/sdk/fsbl/Release/fsbl.elf  $(CURDIR)/build/sdk/system_top/hw/system_top.bit  $(CURDIR)/build/u-boot.elf}" > build_sdimg/overclocks/.boot.bif
	rm -f $(OC_BIN)
	bash -c "source $(VIVADO_SETTINGS) && bootgen -image build_sdimg/overclocks/.boot.bif -o i $(OC_BIN)"
	rm -f build_sdimg/overclocks/.boot.bif
	@python3 -c "$$DIFF_PY" "build_sdimg/BOOT.bin" "$(OC_BIN)" "$(CPU)" "$(MEM)" "build_sdimg/.offsets"
	@echo "Done: $(OC_BIN)"
	@cp scripts/overclock.sh build_sdimg

zip-all: $(TARGETS)
	zip -j build/$(ZIP_ARCHIVE_PREFIX)-fw-$(VERSION).zip $^

dfu-$(TARGET): build/$(TARGET).dfu
	dfu-util -D build/$(TARGET).dfu -a firmware.dfu
	dfu-util -e

dfu-sf-uboot: build/boot.dfu build/uboot-env.dfu
	echo "Erasing u-boot be careful - Press Return to continue... " && read key  && \
		dfu-util -D build/boot.dfu -a boot.dfu && \
		dfu-util -D build/uboot-env.dfu -a uboot-env.dfu
	dfu-util -e

dfu-all: build/$(TARGET).dfu build/boot.dfu build/uboot-env.dfu
	echo "Erasing u-boot be careful - Press Return to continue... " && read key && \
		dfu-util -D build/$(TARGET).dfu -a firmware.dfu && \
		dfu-util -D build/boot.dfu -a boot.dfu  && \
		dfu-util -D build/uboot-env.dfu -a uboot-env.dfu
	dfu-util -e

dfu-ram: build/$(TARGET).dfu
	sshpass -p analog ssh root@$(TARGET) '/usr/sbin/device_reboot ram;'
	sleep 7
	dfu-util -D build/$(TARGET).dfu -a firmware.dfu
	dfu-util -e

uboot-test-ram: u-boot/u-boot
	@echo "Rebooting $(TARGET) into DFU RAM mode..."
	sshpass -p analog ssh root@$(TARGET) '/usr/sbin/device_reboot ram;'
	sleep 7
	@echo "Uploading new u-boot to RAM via DFU..."
	dfu-util -D u-boot/u-boot.bin -a firmware.dfu
	@echo ""
	@echo "u-boot.bin uploaded to RAM. Connect to serial console and run:"
	@echo "  go 0x4000000"
	@echo ""
	@echo "Or if that fails, re-upload as ELF:"
	@echo "  setenv dfu_alt_info \"u-boot.elf ram 0x1000000 0x200000\""
	@echo "  dfu 0 ram 0"
	@echo "  (then: dfu-util -D u-boot/u-boot -a u-boot.elf)"
	@echo "  bootelf 0x1000000"

jtag-bootstrap: build/u-boot.elf build/ps7_init.tcl build/system_top.bit scripts/run.tcl scripts/run-xsdb.tcl
	$(TOOLS_PATH) $(CROSS_COMPILE)strip build/u-boot.elf
	zip -j build/$(ZIP_ARCHIVE_PREFIX)-$@-$(VERSION).zip $^

sysroot: $(BUILDROOT_DIR)/output/images/rootfs.cpio.gz
	tar czfh build/sysroot-$(VERSION).tar.gz --hard-dereference --exclude=usr/share/man --exclude=dev --exclude=etc -C $(BUILDROOT_DIR)/output staging

LINUX_VERSION = $(shell cd linux && git describe --abbrev=4 --dirty --always --tags)
LINUX_URL = https://github.com/analogdevicesinc/linux.git
UBOOT_VER = $(shell cd u-boot && git describe --abbrev=4 --dirty --always --tags)
UBOOT_URL = https://github.com/analogdevicesinc/u-boot.git
HDL_VERSION = $(shell cd hdl && git describe --abbrev=4 --dirty --always --tags)
HDL_URL = https://github.com/analogdevicesinc/hdl

PKG_LINUX = linux,$(LINUX_VERSION),GPL-2.0-only,$(LINUX_URL)
PKG_UBOOT = u-boot,$(UBOOT_VER),GPL-2.0-or-later,$(UBOOT_URL)
PKG_HDL = hdl,$(HDL_VERSION),NOASSERTION,$(HDL_URL)

EXTRA_PKGS = \
	--extra-pkg $(PKG_LINUX) \
	--extra-pkg $(PKG_UBOOT) \
	--extra-pkg $(PKG_HDL)

SBOM_DIR = build/sbom

git-update-all:
	git submodule update --recursive --remote

git-pull:
	git pull --recurse-submodules