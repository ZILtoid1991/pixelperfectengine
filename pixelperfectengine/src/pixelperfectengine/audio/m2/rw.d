module pixelperfectengine.audio.m2.rw;

public import pixelperfectengine.audio.m2.rw_text;
public import std.stdio : File;

public M2File loadM2File(string path) {
    return loadM2File(File(path, "rb"));
}

public M2File loadM2File(F = File)(F src) {
    char[] readbuf;
    readbuf.length = 12;
    src.rawRead(readbuf);
    if (readbuf == "MIDI2.0 VER ") {
        src.seek(0);
        readbuf.length = cast(size_t)src.size();
        src.rawRead(readbuf);
        return loadM2FromText(cast(string)readbuf);
    }
    throw new Exception("Binary file reading not yet implemented");
}