savedcmd_lib/dim/built-in.a := rm -f lib/dim/built-in.a;  printf "lib/dim/%s " dim.o net_dim.o rdma_dim.o | xargs arm-none-linux-gnueabihf-ar cDPrST lib/dim/built-in.a
