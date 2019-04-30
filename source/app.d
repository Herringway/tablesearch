module app;

import std.algorithm;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.meta;
import std.stdio;

struct Match {
	size_t offset;
	size_t distance;
	size_t size;
}

int main(string[] argv)
{
	ulong maxDist = 200;
	string offsetstr = "0";
	ulong minDist = 1;
	bool unsigned = false;
	auto info = getopt(argv, std.getopt.config.bundling,
		   "offset|o", "Offset to start searching at (default: 0)", &offsetstr,
		   "unsigned|u", "Whether or not the values are unsigned (default: false)", &unsigned,
		   "maxdist|m", "Maximum distance between values (default: 200)", &maxDist,
		   "mindist|d", "Minimum distance between values (default: 1)", &minDist);

	if (info.helpWanted || argv.length < 4) {
		defaultGetoptPrinter(format!"Usage: %s file val1 val2 ..."(argv[0]), info.options);
		return 1;
	}

	ulong offset = parseOffset(offsetstr);
	const file = cast(ubyte[])read(argv[1]);

	const searchArrays = buildSearchArrays(argv[2..$].to!(ulong[]), unsigned);
	writefln!"Searching for: %((%([%-(%02X %)]%|, %))%|, %)"(searchArrays);
	Match[] matches;
	while (offset < file.length) {
		foreach (searchArray; searchArrays) {
			if (searchArray[0].length+offset >= file.length) {
				continue;
			}
			if (file[offset..offset+searchArray[0].length] == searchArray[0]) {
				const startDistance = max(searchArray[0].length, minDist);
				enforce(startDistance <= maxDist, "Maximum distance smaller than value size");
				foreach (dist; startDistance..maxDist) {
					bool matched;
					foreach (i, byteSequence; searchArray[1..$]) {
						const newOffset = offset + dist*(i+1);
						const testNext = file[newOffset..newOffset+byteSequence.length];
						if (testNext != byteSequence) {
							matched = false;
							break;
						}
						matched = true;
					}
					if (matched) {
						matches ~= Match(offset, dist, searchArray[0].length);
					}
				}
			}
		}
		offset++;
	}
	foreach (match; matches) {
		writefln!"Found match: 0x%X - %s distance, %s size"(match.offset, match.distance, match.size);
	}
	return 0;
}
ubyte[][][] buildSearchArrays(ulong[] vals, const bool unsigned) @safe {
	ubyte[][][] output;
	ubyte minSize;
	foreach (val; vals) {
		ubyte tmpMin;
		if (unsigned) {
			tmpMin = getValMinSizeUnsigned(val);
		} else {
			tmpMin = getValMinSize(val);
		}
		minSize = max(tmpMin, minSize);
	}
	union ByteArrayHelper(T) {
		ubyte[T.sizeof] raw;
		T value;
	}
	static foreach (Type; AliasSeq!(ubyte, ushort, uint, ulong)) {{
		if (minSize <= Type.sizeof) {
			ubyte[][] byteArrays;
			foreach (val_; vals) {
				ByteArrayHelper!Type val;
				val.value = cast(Type)val_;
				byteArrays ~= val.raw.dup;
			}
			output ~= byteArrays;
		}
	}}
	return output;
}

@safe unittest {
	assert(buildSearchArrays([4], true) ==
		[
			[
				[4]
			],
			[
				[4, 0]
			],
			[
				[4, 0, 0, 0]
			],
			[
				[4, 0, 0, 0, 0, 0, 0, 0]
			]
		]
	);
}

ubyte getValMinSize(long val) @safe {
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
ubyte getValMinSizeUnsigned(ulong val) @safe {
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
int parseOffset(string arg) {
	int offset;
	if ((arg.length > 1) && (arg[1] == 'x'))
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}