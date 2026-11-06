savedcmd_net/ethernet/built-in.a := rm -f net/ethernet/built-in.a;  printf "net/ethernet/%s " eth.o | xargs arm-none-linux-gnueabihf-ar cDPrST net/ethernet/built-in.a
