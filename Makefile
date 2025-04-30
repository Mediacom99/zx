dbuild: 
	zig build 

drun: dbuild
	./zig-out/bin/zhist ~/.histfile

test: 
	zig build test-lh --summary all

clean:
	rm -r ./zig-out


