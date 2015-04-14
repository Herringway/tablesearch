module main;

import std.stdio;
import std.stream;
import std.conv;
import std.getopt;
import std.format;

void printHelp(string progname) {
		stderr.writefln("Usage: %s file val1 val2 ...", progname);
}
void printProgressBar(ulong divisor, ulong dividend) {
	int fill = cast(int)((cast(double)divisor/cast(double)dividend) * 11.0);
	printProgressBar(fill);
}
void printProgressBar(int fill, int length = 10) {
	char[] outputString = new char[length];
	outputString[] = ' ';
	outputString[0..fill] = '=';
	stdout.write("[",outputString,"]\r");
	stdout.flush;
}
int main(string[] argv)
{
	if (argv.length < 4) {
		printHelp(argv[0]);
		return 1;
	}
	ulong maxdist = 1000;
	string offsetstr = "0";
	ulong mindist = 1;
	getopt(argv, std.getopt.config.bundling,
		   "offset|o", &offsetstr, 
		   "maxdist|m", &maxdist, 
		   "mindist|d", &mindist);

	ulong offset = parseOffset(offsetstr);
	std.stream.BufferedFile file = new std.stream.BufferedFile(argv[1], FileMode.In, 0x1000000);
	

	int[] vals = new int[argv.length-2];
	foreach (key, arg; argv[2..$])
		vals[key] = to!int(arg);
	ubyte buf;
	long prevoffset;
	long prevoffset2;
	bool found;
	ulong[] matches;
	int fill = 0;
	printProgressBar(fill);
	file.seekSet(offset);
	while (!file.eof) {
		file.read(buf);
		debug {} else {
			if (cast(int)((cast(double)(file.position - offset)/cast(double)(file.size - offset)) * 10.0) > fill) {
				fill = cast(int)((cast(double)(file.position - offset)/cast(double)(file.size - offset)) * 10.0);
				printProgressBar(fill);
			} 
		}
		if (buf == vals[0]) {
			prevoffset = file.position;
			debug writefln("Found %d at %X", vals[0], file.position);
			while (file.position - prevoffset < maxdist) {
				file.read(buf);
				if (file.position - prevoffset < mindist)
					continue;
				prevoffset2 = file.position;
				if (buf == vals[1]) {
					debug writefln("Found %d at %X", vals[1], file.position);
					found = true;
					foreach (val; vals[2..$]) {
						file.seekCur(prevoffset2 - prevoffset - 1);
						if (file.eof) {
							found = false;
							break;
						}
						file.read(buf);
						debug writefln("%d at %X", buf, file.position);
						if (buf != val) {
							found = false;
							break;
						}
					}
					if (found)
						matches ~= prevoffset;
					file.seekSet(prevoffset2);
				}

			}
		file.seekSet(prevoffset);
		}
	}
	foreach (match; matches)
		writefln("Found match at %d (0x%1$X)", match-1);
	return 0;
}

int parseOffset(string arg) {
	int offset;
	if (arg[1] == 'x')
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}