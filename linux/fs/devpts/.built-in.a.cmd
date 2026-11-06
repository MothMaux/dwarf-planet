savedcmd_fs/devpts/built-in.a := rm -f fs/devpts/built-in.a;  printf "fs/devpts/%s " inode.o | xargs arm-none-linux-gnueabihf-ar cDPrST fs/devpts/built-in.a
