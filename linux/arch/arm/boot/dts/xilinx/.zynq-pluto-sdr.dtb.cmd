savedcmd_arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb := gcc -E -Wp,-MMD,arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.d.pre.tmp -nostdinc -I ./scripts/dtc/include-prefixes -undef -D__DTS__ -x assembler-with-cpp -o arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.dts.tmp arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dts ; ./scripts/dtc/dtc -o arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb -b 0 -iarch/arm/boot/dts/xilinx/ -i./scripts/dtc/include-prefixes -@ -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg   -d arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.d.dtc.tmp arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.dts.tmp ; cat arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.d.pre.tmp arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.d.dtc.tmp > arch/arm/boot/dts/xilinx/.zynq-pluto-sdr.dtb.d 

source_arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb := arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dts

deps_arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb := \
  arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtsi \
  arch/arm/boot/dts/xilinx/zynq.dtsi \
  arch/arm/boot/dts/xilinx/zynq-7000.dtsi \
  scripts/dtc/include-prefixes/dt-bindings/gpio/gpio.h \
  scripts/dtc/include-prefixes/dt-bindings/interrupt-controller/irq.h \

arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb: $(deps_arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb)

$(deps_arch/arm/boot/dts/xilinx/zynq-pluto-sdr.dtb):
