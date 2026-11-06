savedcmd_vmlinux.o := arm-none-linux-gnueabihf-ld -EL -z noexecstack --no-warn-rwx-segments -r -o vmlinux.o   --whole-archive vmlinux.a --no-whole-archive --start-group  --end-group 
