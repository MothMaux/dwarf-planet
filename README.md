# Firmware for pluto-based SDRs

Made to be a minimal, performance-first firmware project for SDRs

Features:
- CS8 mode compatible with [GobDump](https://github.com/MTalon63/GobDump)
- Overclocking

Current changes:
- Updated to the 0.39r tag of plutosdr-fw for linux, u-boot, and buildroot. HDL updated to 4840c81
- Added LibreSDR Board (verified working)
- Fixed sdboot loading environment values

Roadmap:
- Add more boards
- Add release files
- Debloating
- More easily switch modes for certain features

# Build Instructions
```bash
 sudo apt-get install git build-essential fakeroot libncurses5-dev libssl-dev ccache
 sudo apt-get install dfu-util u-boot-tools device-tree-compiler mtools
 sudo apt-get install bc python3 cpio zip unzip rsync file wget
 git clone --recursive https://github.com/mothmaux/dwarf-planet.git
 cd dwarf-planet
 export VIVADO_SETTINGS=/tools/Xilinx/2025.1/Vivado/settings64.sh
 make TARGET=$target
 make sdimg TARGET=$target
 # Optional if you want to make overclocks, creates an overclocked bin and records address offsets.
 make sdimg_oc TARGET=$target CPU=40 MEM=28

```
* Build targets

    PlutoSDR : pluto (default)
    LibreSDR : libre
    Fishball : fishball7010
             : fishball7020
    AntSDR   : ant
    NanoSDR  : nano

* Common issues when building

For errors about `xsct` when building, ensure that Vitis / Vitis Unified XX is installed and sourced. Vitis HLS is not the same.
For improper usage errors, uninstall the apt package xsct which is a different package for x11

For errors when building the hdl/projects/$target make sure that you have set the source for Vivado & added sufficient permissions for the user that executed `make`

* Overclocking
Releases are yet to come, but will include all needed files for overclocking. 
```bash
cd ./build_sdimg
bash ./overclock.sh 40 28
# replace with your chosen CLK multipliers
cp ./overclocks/FSBL_40_28 ./BOOT.bin
cp ./* /your/sd/card/
```

* Repository layout

     | Submodule  | Comment |
     | ------------- | ------------- |
     | linux | ADI Linux kernel tree |
     | u-boot | ADI u-boot tree |
     | hdl | ADI HDL designs used to build the FPGA bitstream |
     | buildroot | Buildroot tree used to build the toolchain and root filesystem |
     | br2-external | Buildroot external tree with the ADI board files (board/adi/pluto) and defconfigs |


 
 * Main targets
 
     | File  | Comment |
     | ------------- | ------------- | 
     | pluto.frm | Main PlutoSDR firmware file used with the USB Mass Storage Device |
     | pluto.dfu | Main PlutoSDR firmware file used in DFU mode |
     | boot.frm  | First and Second Stage Bootloader (u-boot + fsbl + uEnv) used with the USB Mass Storage Device |
     | boot.dfu  | First and Second Stage Bootloader (u-boot + fsbl) used in DFU mode |
     | uboot-env.dfu  | u-boot default environment used in DFU mode |
     | plutosdr-fw-vX.XX.zip  | ZIP archive containing all of the files above |  
     | plutosdr-jtag-bootstrap-vX.XX.zip  | ZIP archive containing u-boot and Vivado TCL used for JTAG bootstrapping |       
 
  * Other intermediate targets

     | File  | Comment |
     | ------------- | ------------- |
     | boot.bif | Boot Image Format file used to generate the Boot Image |
     | boot.bin | Final Boot Image |
     | pluto.frm.md5 | md5sum of the pluto.frm file |
     | pluto.itb | u-boot Flattened Image Tree |
     | rootfs.cpio.gz | The Root Filesystem archive |
     | sbom | Software Bill of Materials (CycloneDX) for buildroot, linux, u-boot, hdl and the full firmware |
     | sdk | Vivado/Vitis Build folder including the FSBL |
     | system_top.bit | FPGA Bitstream (from XSA) |
     | system_top.xsa | FPGA Hardware Description File exported by Vivado |
     | u-boot.elf | u-boot ELF Binary |
     | uboot-env.bin | u-boot default environment in binary format created from uboot-env.txt |
     | uboot-env.txt | u-boot default environment in human readable text format |
     | zImage | Compressed Linux Kernel Image |
     | zynq-pluto-sdr.dtb | Device Tree Blob for Rev.A |
     | zynq-pluto-sdr-revb.dtb | Device Tree Blob for Rev.B|     
     | zynq-pluto-sdr-revc.dtb | Device Tree Blob for Rev.C|
 
* To add a board layout:
add target to list in ./makefile

add defconfigs in 

`./u-boot/configs/zynq_x_defconfig` \
`./linux/arch/arm/configs/zynq_x_defconfig` \
`./br2-external/configs/zynq_x_defconfig` 

add board project files in ~/br2-external/buildroot/boards