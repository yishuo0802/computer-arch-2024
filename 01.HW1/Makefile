all: mul_complex.exe
	./mul_complex.exe

mul_complex.exe: mul_complex.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS) -lm
	cc -o mul_complex.exe mul_complex.c -lm