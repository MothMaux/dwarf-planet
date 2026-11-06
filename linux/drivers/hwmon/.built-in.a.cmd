savedcmd_drivers/hwmon/built-in.a := rm -f drivers/hwmon/built-in.a;  printf "drivers/hwmon/%s " hwmon.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/hwmon/built-in.a
