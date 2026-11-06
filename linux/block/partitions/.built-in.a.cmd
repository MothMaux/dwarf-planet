savedcmd_block/partitions/built-in.a := rm -f block/partitions/built-in.a;  printf "block/partitions/%s " core.o msdos.o efi.o | xargs arm-none-linux-gnueabihf-ar cDPrST block/partitions/built-in.a
