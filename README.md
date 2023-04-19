# LaserDrop
KJ Newman, Anju Ito, and Roger Lacson Senior Capstone

To compile code, run:
gcc send_library.c receive_library.c queue.c protocol_1024.c -o test -Wall -Wextra -lftd2xx -lpthread -lobjc -framework IOKit -framework CoreFoundation -Wl,-rpath /usr/local/lib -L/usr/local/lib