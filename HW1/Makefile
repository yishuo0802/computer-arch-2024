all: main.exe
	./main.exe

main.exe: main.c pow.c float.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)