savedcmd_net/packet/built-in.a := rm -f net/packet/built-in.a;  printf "net/packet/%s " af_packet.o | xargs arm-none-linux-gnueabihf-ar cDPrST net/packet/built-in.a
