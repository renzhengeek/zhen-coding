The code is used to test R/W the same inode exported by ocfs2
from different nodes.

The idea of this code is to write/read from the begin to the
end of a file. Each loop involves x times of W/R. Then print out
the time each loop takes.

1. build
g++ writer.cpp -o iomaker

2. run on writing node
./iomaker -w -v -l -1 /mnt/shared/file 1000

p.s:
 "-w" is to write, "-v" means verbose, "-l" is to loop infinitely,
 "file" is the shared file, "1000" means 1000 times of W/R each loop.

3. run on reading node
./iomaker -v -l -1 /mnt/shared/file 1000

