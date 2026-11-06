savedcmd_drivers/iio/addac/built-in.a := rm -f drivers/iio/addac/built-in.a;  printf "drivers/iio/addac/%s " one-bit-adc-dac.o | xargs arm-none-linux-gnueabihf-ar cDPrST drivers/iio/addac/built-in.a
