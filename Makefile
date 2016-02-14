$(CC)=gcc

windows: aliaser.dll

lunix: aliaser.so

aliaser.dll: aliaser.o
	gcc -shared -o aliaser.dll aliaser.o

aliaser.so: aliaser.o
	gcc -shared -o aliaser.so aliaser.o

aliaser.o: aliaser.c
	gcc -c aliaser.c

clean:
	rm aliaser.o aliaser.dll aliaser.so
