all: pow.exe
	./pow.exe

pow.exe: pow.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS) -lm
	cc -o pow.exe pow.c -lm