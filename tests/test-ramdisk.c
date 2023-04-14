/*
 i386-tcc -vv -static -L/lib -I/include -nostdlib -c  -o test.o test.c
 i386-tcc -vv -static -L/lib -I/include -nostdlib -o test /lib/crt1.o test.o /lib/libc.a
*/

#include <stdio.h>

int main( int argc, char *argv[] )
{
    puts( "hello i486tcc" );
    return 0;
}
