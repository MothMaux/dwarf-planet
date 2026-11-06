savedcmd_drivers/dax/built-in.a := rm -f drivers/dax/built-in.a;  printf "drivers/dax/%s " hmem/built-in.a | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/dax/built-in.a
