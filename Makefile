build: 
	zig build 

drun: build
	./zig-out/bin/zhist ./assets/histfile

test: 
	zig build test-lh --summary all

clean:
	rm -r ./zig-out


