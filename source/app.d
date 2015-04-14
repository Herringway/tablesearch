module main;

import std.stdio;
import std.stream;
import std.conv;
import std.getopt;
import std.format;
import std.algorithm;
import std.array;

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
	ulong maxdist = 200;
	string offsetstr = "0";
	ulong mindist = 1;
	bool unsigned = false;
	getopt(argv, std.getopt.config.bundling,
		   "offset|o", &offsetstr,
		   "unsigned|u", &unsigned,
		   "maxdist|m", &maxdist,
		   "mindist|d", &mindist);

	ulong offset = parseOffset(offsetstr);
	std.stream.BufferedFile file = new std.stream.BufferedFile(argv[1], FileMode.In, 0x1000000);
	
	long[] vals = array(map!((x) => to!long(x))(argv[2..$]));
	ulong[] vals_unsigned = array(map!((x) => to!ulong(x))(argv[2..$]));
	ubyte buf;
	ulong prevoffset;
	ulong[] matches;
	int fill = 0;
	file.seekSet(offset);
	auto size = file.size;
	auto readSize = 1;
	if (unsigned)
		foreach (val; vals_unsigned)
			readSize = max(getValMinSizeUnsigned(val), readSize);
	else
		foreach (val; vals)
			readSize = max(getValMinSize(val), readSize);
	writefln("Using value size %d", readSize);
	printProgressBar(fill);
	while (!file.eof) {
		prevoffset = file.position;
		if (cast(int)((cast(double)(prevoffset - offset)/cast(double)(size - offset)) * 10.0) > fill) {
			fill = cast(int)((cast(double)(prevoffset - offset)/cast(double)(size - offset)) * 10.0);
			printProgressBar(fill);
		} 
		if (unsigned) {
			if (file.readVarValUnsigned(readSize) == vals_unsigned[0]) {
				foreach (distance; mindist..maxdist)
					if (readDistanceUnsigned(file, prevoffset, distance, vals.length - 1, readSize) == vals_unsigned[1..$])
						matches ~= prevoffset;
			}
		} else {
			if (file.readVarVal(readSize) == vals[0]) {
				foreach (distance; mindist..maxdist)
					if (        readDistance(file, prevoffset, distance, vals.length - 1, readSize) == vals[1..$])
						matches ~= prevoffset;
			}
		}
		file.seekSet(prevoffset+readSize);
	}
	foreach (match; matches)
		writefln("Found match at %d (0x%1$X)", match-1);
	return 0;
}
uint getValMinSize(long val) {
	if (val > 0x7FFFFFFFFFFFFF)
		return 8;
	else if (val > 0x7FFFFFFFFFFF)
		return 7;
	else if (val > 0x7FFFFFFFFF)
		return 6;
	else if (val > 0x7FFFFFFF)
		return 5;
	else if (val > 0x7FFFFF)
		return 4;
	else if (val > 0x7FFF)
		return 3;
	else if (val > 0x7F)
		return 2;
	return 1;
}
uint getValMinSizeUnsigned(ulong val) {
	if (val > 0xFFFFFFFFFFFFFF)
		return 8;
	else if (val > 0xFFFFFFFFFFFF)
		return 7;
	else if (val > 0xFFFFFFFFFF)
		return 6;
	else if (val > 0xFFFFFFFF)
		return 5;
	else if (val > 0xFFFFFF)
		return 4;
	else if (val > 0xFFFF)
		return 3;
	else if (val > 0xFF)
		return 2;
	return 1;
}
ulong[] readDistanceUnsigned(std.stream.BufferedFile file, ulong offset, ulong distance, uint count, uint readSize) {
	ulong[] output;
	foreach (id; 0..count) {
		file.seekSet(offset + distance * (id+1));
		output ~= file.readVarValUnsigned(readSize);
	}
	return output;
}
long[] readDistance(std.stream.BufferedFile file, ulong offset, ulong distance, uint count, uint readSize) {
	long[] output;
	foreach (id; 0..count) {
		file.seekSet(offset + distance * (id+1));
		output ~= file.readVarVal(readSize);
	}
	return output;
}
long readVarVal(std.stream.BufferedFile file, uint readSize) {
	ulong temp = file.readVarValUnsigned(readSize);
	if ((temp & (1<<(readSize*8-1))) != 0)
		return cast(long)((cast(long)0x8000000000000000) >> (64-readSize*8-1) | temp);
	return cast(long)temp;
}
ulong readVarValUnsigned(std.stream.BufferedFile file, uint readSize) {
	ulong temp;
	ubyte buf;
	foreach (i; 0..readSize) {
		file.read(buf);
		temp |= cast(ulong)buf<<(i*8);
	}
	return temp;
}
int parseOffset(string arg) {
	int offset;
	if ((arg.length > 1) && (arg[1] == 'x'))
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}