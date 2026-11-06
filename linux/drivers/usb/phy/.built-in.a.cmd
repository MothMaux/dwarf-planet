savedcmd_drivers/usb/phy/built-in.a := rm -f drivers/usb/phy/built-in.a;  printf "drivers/usb/phy/%s " of.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/usb/phy/built-in.a
