module pixelperfectengine.audio.modules.pcm8;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;

import midi2.types.structs;
import midi2.types.enums;

import bitleveld.datatypes;

/**
PCM8 - implements a sample-based synthesizer.

It has support for 
 * 8 bit and 16 bit linear PCM
 * Mu-Law and A-Law PCM
 * IMA ADPCM
 * Dialogic ADPCM

The module has 8 sample-based channels with looping capabilities and each has an ADSR envelop, and 4 outputs with a filter.
*/
public class PCM8 {
	/**
	Defines a single sample.
	*/
	protected struct Sample {
		///Stores sample data, which later can be decompressed
		ubyte[]		sampleData;
		///Stores what kind of format the sample has
		WaveFormat	format;
	}
	/**
	Defines a single sample-channel assignment.
	*/
	protected struct SampleAssignment {
		///Number of sample that is assigned.
		uint		sampleNum;
		///The base frequency of the sample.
		///Overrides the format definition.
		float		baseFreq;
		///The base note of the sample.
		ubyte		baseNote;
		///The lowest note that is assigned to this sample.
		ubyte		low;
		///The highest note that is assigned to this sample.
		ubyte		high;
	}
}