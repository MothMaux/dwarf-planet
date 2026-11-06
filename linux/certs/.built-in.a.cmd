savedcmd_certs/built-in.a := rm -f certs/built-in.a;  printf "certs/%s " system_keyring.o system_certificates.o | xargs arm-none-linux-gnueabihf-ar cDPrST certs/built-in.a
