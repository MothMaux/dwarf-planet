savedcmd_drivers/usb/roles/built-in.a := rm -f drivers/usb/roles/built-in.a;  printf "drivers/usb/roles/%s " class.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/usb/roles/built-in.a
