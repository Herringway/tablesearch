module app;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.meta;
import std.stdio;

import pixelatrix;
import magicalrainbows;

struct Match {
	size_t offset;
	size_t distance;
	size_t size;
}

struct Options {
	size_t offset = 0;
	ulong maxDist = 200;
	ulong minDist = 1;
	bool colourSearch;
	SupportedFormat colourFormat = SupportedFormat.bgr555;
	bool unsigned = false;
	ulong firstID = 0;
}

int main(string[] argv)
{
	Options options;
	auto info = getopt(argv, std.getopt.config.bundling,
		   "offset|o", "Offset to start searching at (default: 0)", (string s, string o) { options.offset = parseOffset(o); },
		   "unsigned|u", "Whether or not the values are unsigned (default: false)", &options.unsigned,
		   "first-id", "The id associated with the first value specified (default: 0)", &options.firstID,
		   "coloursearch|c", "Whether or not to look for colours instead of integers (default: false)", &options.colourSearch,
		   "colourformat|f", "Format of colours to look for (default: BGR555)", &options.colourFormat,
		   "maxdist|m", "Maximum distance between values (default: 200)", &options.maxDist,
		   "mindist|d", "Minimum distance between values (default: 1)", &options.minDist);

	if (info.helpWanted || argv.length < 4) {
		defaultGetoptPrinter(format!"Usage: %s file val1 val2 ..."(argv[0]), info.options);
		return 1;
	}

	const file = cast(ubyte[])read(argv[1]);

	Match[] matches;

	if (options.colourSearch) {
		matches = searchFor(buildColourSearchArray(argv[2..$], options.colourFormat), file, options);
	} else {
		matches = searchFor(buildSearchArrays(argv[2..$].map!parseOffset.array, options.unsigned), file, options);
	}
	foreach (match; matches) {
		writefln!"Found match: 0x%X - %s distance, %s size - potential start points: 0x%X - 0x%X"(match.offset, match.distance, match.size, match.offset - (options.firstID + 1) * match.distance, match.offset - options.firstID * match.distance);
	}
	return 0;
}
auto searchFor(const ubyte[][][] searchArrays, const ubyte[] file, const Options options) @safe {
	writefln!"Searching for: %((%([%-(%02X %)]%|, %))%|, %)"(searchArrays);
	Match[] matches;
	size_t offset = options.offset;
	while (offset < file.length) {
		foreach (searchArray; searchArrays) {
			if (searchArray[0].length+offset >= file.length) {
				continue;
			}
			if (file[offset..offset+searchArray[0].length] == searchArray[0]) {
				const startDistance = max(searchArray[0].length, options.minDist);
				enforce(startDistance <= options.maxDist, "Maximum distance smaller than value size");
				foreach (dist; startDistance..options.maxDist) {
					bool matched;
					foreach (i, byteSequence; searchArray[1..$]) {
						const newOffset = offset + dist*(i+1);
						if (newOffset+byteSequence.length >= file.length) {
							matched = false;
							break;
						}
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
	return matches;
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

ubyte[][][] buildColourSearchArray(string[] vals, SupportedFormat format) @safe {
	ubyte[][] output;
	foreach (val; vals) {
		ubyte r, g, b;
		val.formattedRead!"%s,%s,%s"(r, g, b);
		ubyte[] tmp;
		tmp ~= colourToBytes(r, g, b, format);
		output ~= tmp;
	}
	return [output];
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
ulong parseOffset(string arg) {
	ulong offset;
	if ((arg.length > 1) && (arg[1] == 'x'))
		formattedRead(arg, "0x%x", &offset);
	else
		formattedRead(arg, "%s", &offset);
	return offset;
}