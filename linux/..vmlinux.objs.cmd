savedcmd_.vmlinux.objs := for f in vmlinux.a; do case $${f} in *libgcc.a) ;; *) arm-none-linux-gnueabihf-ar t $${f} ;; esac done > .vmlinux.objs
