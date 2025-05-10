build: 
	zig build --summary all

build-release:
	zig build --release=fast

run: build
	./zig-out/bin/zhist ./assets/histfile > app.log 2>&1

run-release: build-release
	./zig-out/bin/zhist ./assets/histfile

test: 
	zig build test-lh --summary all

clean:
	rm -r ./zig-out
