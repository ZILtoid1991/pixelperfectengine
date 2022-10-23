module pixelperfectengine.system.wavfile;

static import std.file;
import std.format;
import std.exception : enforce;


/// parse little-endian ushort
private ushort toUshort(const ubyte[] array, uint offset) {
   // friggin' order of operations had me bughunt for half an hour
   return cast(ushort)(array[offset] + (array[offset+1]<<8));
}

/// parse little-endian uint
private uint toUint(const ubyte[] array, uint offset) {
   return array[offset] + (array[offset+1]<<8) + (array[offset+2]<<16) + (array[offset+3]<<24);
}

/**
Basic WAV file loader
TO DO: Make some more specific exceptions by final version 0.10.0!
*/
class WavFile {
   /**
   WAV file header
   */
   struct WavHeader {
      immutable uint size; /// number of bytes after this (overall file size - 8)
      immutable ushort format; /// type of format. 1 means PCM
      immutable ushort channels; /// no. of channels
      immutable uint samplerate; /// samples per second
      immutable uint bytesPerSecond; /// samplerate * bitsPerSample * channels / 8
      immutable ushort bytesPerSample; /// bitsPerSample * channels / 8
      immutable ushort bitsPerSample; /// bits per sample - 8-16-etc
      immutable uint dataSize; /// size of data section
      /**
      default constructor from raw WAV file data
      */
      this (const ubyte[] rawData) {
         // this *might* be out of spec, as in theory fmt chunks could be bigger if indicated by offset 16-20 (uint)
         // so any offset above 35 should be dynamicall calculated
         // but I don't think there's any WAV files like that
         enforce(rawData[0..4] == "RIFF", new Exception("Header corrupted: 'RIFF' string missing"));
         enforce(rawData[8..12] == "WAVE", new Exception("Header corrupted: 'WAVE' string missing"));
         enforce(rawData[12..16] == "fmt ", new Exception("Header corrupted: 'fmt ' string missing"));
         enforce(rawData[36..40] == "data", new Exception("Header corrupted: 'data' string missing"));
         this.size = toUint(rawData, 4);
         this.format = toUshort(rawData, 20);
         this.channels = toUshort(rawData, 22);
         this.samplerate = toUint(rawData, 24);
         this.bytesPerSecond = toUint(rawData, 28);
         this.bytesPerSample = toUshort(rawData, 32);
         this.bitsPerSample = toUshort(rawData, 34);
         this.dataSize = toUint(rawData, 40);

         assert(
            this.bytesPerSecond == this.bitsPerSample * this.samplerate * this.channels / 8,
            .format(
               "Header corrupted: stored bytes per second value %s does not match calculated value %s",
               this.bytesPerSecond, 
               this.bitsPerSample * this.samplerate * this.channels / 8
            )
         );

         assert(
            this.bytesPerSample == this.bitsPerSample * this.channels / 8,
            .format(
               "Header corrupted: stored bytes per sample value %s does not match calculated value %s",
               this.bytesPerSample,
               this.bitsPerSample * this.channels / 8
            )
         );

         assert(
            this.dataSize == this.size - 44 + 8,
            .format(
               "Header corrupted: data size and file size does not add up!"
            )
         );
      }
   }

   // samples always start at offset 44
   // but their interpretation depends on the header
   public immutable ubyte[] rawData; /// raw file contents
   public immutable WavHeader header; /// header info


   /// load a wav file from path
   this(string filename) {
      rawData = cast(immutable(ubyte[]))std.file.read(filename);
      this.header = WavHeader(this.rawData[0..44]);
      enforce(this.header.size + 8 == this.rawData.length, new Exception(format(
         "File size is corrupted: size is %s but it should be %s", 
         this.header.size, this.rawData.length - 8))
      );
   }



}
