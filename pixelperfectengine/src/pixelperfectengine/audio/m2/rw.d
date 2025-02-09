module pixelperfectengine.audio.m2.rw;

public import pixelperfectengine.audio.m2.rw_text;
public import pixelperfectengine.audio.m2.rw_bin;
public import std.stdio : File;

public M2File loadIMBCFile(string path) {
    return loadIMBCFile(File(path, "rb"));
}

public M2File loadIMBCFile(F = File)(F src) {
    char[] readbuf;
    readbuf.length = 12;
    src.rawRead(readbuf);
    if (readbuf == "MIDI2.0 VER ") {
        src.seek(0);
        readbuf.length = cast(size_t)src.size();
        src.rawRead(readbuf);
        return IMBCAssembler(cast(string)readbuf).compile();
    } else if (readbuf == "MIDI2.0B\0\0\0\0") {
		src.seek(0);
        readbuf.length = cast(size_t)src.size();
        src.rawRead(readbuf);
        return readIMBCBin(cast(ubyte[])readbuf);
    }
    throw new Exception("Binary file reading not yet implemented");
}

public void saveIMBCFile(F = File)(M2File src, F dest, bool binary = true) {
	ubyte[] writeBuf = writeIMBCBin(src);
	dest.rawWrite(writeBuf);
}
