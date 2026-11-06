savedcmd_fs/kernfs/built-in.a := rm -f fs/kernfs/built-in.a;  printf "fs/kernfs/%s " mount.o inode.o dir.o file.o symlink.o | xargs arm-none-linux-gnueabihf-ar cDPrST fs/kernfs/built-in.a
