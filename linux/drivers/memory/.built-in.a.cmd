savedcmd_drivers/memory/built-in.a := rm -f drivers/memory/built-in.a;  printf "drivers/memory/%s " pl353-smc.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/memory/built-in.a
