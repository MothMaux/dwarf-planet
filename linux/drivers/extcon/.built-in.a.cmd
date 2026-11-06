savedcmd_drivers/extcon/built-in.a := rm -f drivers/extcon/built-in.a;  printf "drivers/extcon/%s " extcon.o devres.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/extcon/built-in.a
