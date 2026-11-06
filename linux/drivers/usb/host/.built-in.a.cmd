savedcmd_drivers/usb/host/built-in.a := rm -f drivers/usb/host/built-in.a;  printf "drivers/usb/host/%s " ehci-hcd.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/usb/host/built-in.a
