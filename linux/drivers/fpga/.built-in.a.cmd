savedcmd_drivers/fpga/built-in.a := rm -f drivers/fpga/built-in.a;  printf "drivers/fpga/%s " fpga-mgr.o zynq-fpga.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/fpga/built-in.a
