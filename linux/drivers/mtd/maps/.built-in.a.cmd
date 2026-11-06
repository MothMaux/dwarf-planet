savedcmd_drivers/mtd/maps/built-in.a := rm -f drivers/mtd/maps/built-in.a;  printf "drivers/mtd/maps/%s " physmap-core.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/mtd/maps/built-in.a
