module pixelperfectengine.audio.base.handler;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.handler module.
 */

import core.thread;
import core.time;

import std.conv : to;
import std.string : fromStringz;
import std.bitmanip : bitfields;

import pixelperfectengine.system.exc;
//import pixelperfectengine.system.etc : isPowerOf2;
import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.midiseq;

import iota.audio.output;
import iota.audio.device;
public import iota.audio.types;

/**
 * Manages and initializes audio devices.
 *
 * Important: Only one instance should be made.
 */
public class AudioDeviceHandler {
	package AudioDevice				device;			///Contains the initialized audio device
	protected AudioSpecs			specs;			///Contains the requested/given audio specs
	package int						blockSize;		///Requested/given buffer base size / block length (in samples)
	package int						nOfBlocks;		///Requested/given number of blocks before they get sent to the output
	/** 
	 * Creates an instance, and detects all drivers.
	 * Params:
	 *   specs = Requested audio specifications. If not available, a nearby will be used instead.
	 *   channels = Number of channels
	 *   buffSize = The size of the buffer in samples
	 *
	 * Throws: an AudioInitException if audio is failed to be initialized.
	 */
	public this(AudioSpecs specs, int blockSize, int nOfBlocks) {
		//context = soundio_create();
		this.specs = specs;
		this.blockSize = blockSize;
		this.nOfBlocks = nOfBlocks;
		//req.callback = &callbacksFromSDL;
	}
	///Destructor
	~this() {
		
	}
	/**
	 * Initializes an audio driver by ID.
	 *
	 * Throws an AudioInitException if audio failed to be initialized.
	 */
	public static void initAudioDriver(DriverType backend) {
		int errCode = initDriver(backend);
		if (errCode) throw new AudioInitException("Failed to initialize audio driver. Error code: " ~ errCode.to!string);
	}
	/**
	 * Opens a specific audio device for audio playback by ID, then sets the values for buffer sizes etc.
	 *
	 * Throws an AudioInitException if audio failed to be initialized
	 */
	public void initAudioDevice(int id = -1) {
		int errCode = openDevice(id, device);
		if (errCode) throw new AudioInitException("Failed to initialize audio device. Error code: " ~ errCode.to!string);
		int recSlmpRate = device.getRecommendedSampleRate();
		if (recSlmpRate > 0) {
			specs.sampleRate = recSlmpRate;
		}
		switch (specs.sampleRate) {
			case 88_200, 96_000:
				blockSize *= 2;
				specs.bufferSize_slmp *= 2;
				break;
			case 176_400, 192_000:
				blockSize *= 4;
				specs.bufferSize_slmp *= 4;
				break;
			default:
				break;
		}
		specs = device.requestSpecs(specs);
		// Recalculate block sizes if buffer size changed
		if (specs.bufferSize_slmp != blockSize * nOfBlocks) {
			if (!(specs.bufferSize_slmp % 4)) {
				blockSize = specs.bufferSize_slmp / 4;
				nOfBlocks = 4;
			} else {
				blockSize = specs.bufferSize_slmp;
				nOfBlocks = 1;
			}
		}
	}
	/**
	 * Return an array with the names of the available audio devices.
	 */
	public string[] getDevices() {
		return getOutputDeviceNames();
	}
	/**
	 * Returns the available sampling frequency.
	 */
	public int getSamplingFrequency() @nogc @safe pure nothrow const {
		return specs.sampleRate;
	}
	/**
	 * Returns the number of audio channels.
	 */
	public int getChannels() @nogc @safe pure nothrow const {
		return specs.outputChannels;
	}
	/**
	 * Returns the buffer size in units.
	 */
	public size_t getBufferSize() @nogc @safe pure nothrow const {
		return blockSize * nOfBlocks;
	}
	/** 
	 * Returns the buffer length in time, in `Duration` format.
	 */
	public Duration getBufferDelay() @nogc @safe pure nothrow const {
		return specs.bufferSize_time;
	}
}
/**
 * Manages all audio modules complete with routing, MIDI2.0, etc.
 */
public class ModuleManager {
	protected int			blockSize;		///Rendering buffer size in samples, also the length of a single frame.
	protected int			nOfBlocks;		///Number of maximum frames that can be put into the output buffer.
	protected int			currBlock;		///Current audio frame.
	//protected int			itrn_blockSize;	///Internal block size after upsampling.
	protected int			itrn_sampleRate;///Internal sample rate before upsampling.
	///Pointer to the audio device handler.
	public AudioDeviceHandler	devHandler;
	///Pointer to a MIDI sequencer, for synchronizing it with the audio stream.
	public Sequencer		midiSeq;
	protected OutputStream	outStrm;		///Output stream handling.
	/**
	 * List of modules.
	 *
	 * Ran in order, should be ordered in such way to ensure that routing is correct, and the modules that need the
	 * input will get some.
	 */
	public AudioModule[]	moduleList;
	/**
	 * List of pointers to input buffers.
	 *
	 * Order of first dimension must match the modules. Pointers can be shared between multiple inputs or outputs.
	 * If a specific plugin doesn't have any inputs, then an array with zero elements must be added.
	 */
	protected float*[][]	inBufferList;
	/**
	 * List of pointers to output buffers.
	 *
	 * Order of first dimension must match the modules. Pointers can be shared between multiple inputs or outputs.
	 * If a specific plugin doesn't have any outputs, then an array with zero elements must be added.
	 */
	protected float*[][]	outBufferList;
	/**
	 * List of the buffers themselves.
	 *
	 * One buffer can be shared between multiple input and/or output for mixing, etc.
	 * All buffers must have the same size, defined by the variable `blockSize`
	 * The first buffers are used for output rendering.
	 */
	protected float[][]		buffers;
	/**
	 * Final output buffer.
	 *
	 * Words are in LRLRLR... order, or similar, depending on number of channels.
	 */
	protected float[]		finalBuffer;
	protected int			channels;
	/** 
	 * Creates an instance of a module handler.
	 * Params:
	 *  handler = The AudioDeviceHandler that contains the data about the audio device.
	 */
	public this(AudioDeviceHandler handler) {
		import pixelperfectengine.audio.base.func : resetBuffer;
		devHandler = handler;
		//this.blockSize = handler.blockSize;
		outStrm = handler.device.createOutputStream();
		if (outStrm is null) throw new AudioInitException("Audio stream couldn't be opened.");
		this.nOfBlocks = handler.nOfBlocks;
		
		this.channels = handler.getChannels();
		
		switch (handler.getSamplingFrequency) {
			case 44_100, 48_000:
				outStrm.callback_buffer = &audioCallback;
				blockSize = handler.blockSize;
				itrn_sampleRate = handler.getSamplingFrequency;
				break;
			case 88_200, 96_000:
				outStrm.callback_buffer = &audioCallback2_2;
				blockSize = handler.blockSize / 2;
				itrn_sampleRate = handler.getSamplingFrequency / 2;
				break;
			case 176_400, 192_000:
				outStrm.callback_buffer = &audioCallback2_4;
				blockSize = handler.blockSize / 4;
				itrn_sampleRate = handler.getSamplingFrequency / 4;
				break;
			default:
				break;
		}
		finalBuffer.length = handler.getChannels() * blockSize * nOfBlocks;
		//itrn_blockSize = cast(int)finalBuffer.length;
		resetBuffer(finalBuffer);
		buffers.length = handler.getChannels();
		for (int i ; i < buffers.length ; i++) {
			buffers[i].length = blockSize;
			resetBuffer(buffers[i]);
		}
		//super(&render);
	}
	/**
	 * Audio callback function.
	 * Renders the audio, then it copies to the destination buffer. No upsampling and/or conversion.
	 */
	protected void audioCallback(ubyte[] destbuffer) @nogc nothrow {
		import pixelperfectengine.audio.base.func : interleave, resetBuffer;
		import core.stdc.string : memcpy;

		while (currBlock < nOfBlocks) {
			foreach (ref key; buffers) {
				resetBuffer(key);
			}
			foreach (size_t i, AudioModule am; moduleList) {
				am.renderFrame(inBufferList[i], outBufferList[i]);
			}
			if (midiSeq !is null)
				midiSeq.lapseTime(devHandler.getBufferDelay);
			const size_t offset = currBlock * blockSize * channels;
			interleave(blockSize, buffers[0].ptr, buffers[1].ptr, finalBuffer.ptr + offset);
			currBlock++;
		}
		currBlock = 0;
		
		memcpy(destbuffer.ptr, finalBuffer.ptr, destbuffer.length);
	}
	/**
	 * Audio callback function.
	 * Renders the audio, then it copies to the destination buffer. 2x upsampling.
	 */
	protected void audioCallback2_2(ubyte[] destbuffer) @nogc nothrow {
		import pixelperfectengine.audio.base.func : interleave, resetBuffer, upsampleStereo;
		import core.stdc.string : memcpy;

		while (currBlock < nOfBlocks) {
			foreach (ref key; buffers) {
				resetBuffer(key);
			}
			foreach (size_t i, AudioModule am; moduleList) {
				am.renderFrame(inBufferList[i], outBufferList[i]);
			}
			if (midiSeq !is null)
				midiSeq.lapseTime(devHandler.getBufferDelay);
			const size_t offset = currBlock * blockSize * channels;
			interleave(blockSize, buffers[0].ptr, buffers[1].ptr, finalBuffer.ptr + offset);
			currBlock++;
		}
		currBlock = 0;
		upsampleStereo(finalBuffer.length, 2, finalBuffer.ptr, cast(float*)destbuffer.ptr);
		//memcpy(destbuffer.ptr, finalBuffer.ptr, destbuffer.length);
	}
	/**
	 * Audio callback function.
	 * Renders the audio, then it copies to the destination buffer. 4x upsampling.
	 */
	protected void audioCallback2_4(ubyte[] destbuffer) @nogc nothrow {
		import pixelperfectengine.audio.base.func : interleave, resetBuffer, upsampleStereo;
		import core.stdc.string : memcpy;

		while (currBlock < nOfBlocks) {
			foreach (ref key; buffers) {
				resetBuffer(key);
			}
			foreach (size_t i, AudioModule am; moduleList) {
				am.renderFrame(inBufferList[i], outBufferList[i]);
			}
			if (midiSeq !is null)
				midiSeq.lapseTime(devHandler.getBufferDelay);
			const size_t offset = currBlock * blockSize * channels;
			interleave(blockSize, buffers[0].ptr, buffers[1].ptr, finalBuffer.ptr + offset);
			currBlock++;
		}
		currBlock = 0;
		upsampleStereo(finalBuffer.length, 4, finalBuffer.ptr, cast(float*)destbuffer.ptr);
		//memcpy(destbuffer.ptr, finalBuffer.ptr, destbuffer.length);
	}
	/**
	 * MIDI commands are received here from modules.
	 *
	 * data: up to 128 bits of MIDI 2.0 commands. Any packets that are shorter should be padded with zeros.
	 * offset: time offset of the command. This can reduce jitter caused by the asynchronous operation of the 
	 * sequencer and the audio plugin system.
	 */
	public void midiReceive(uint[4] data, uint offset) @nogc nothrow {
		
	}
	/**
	 * Sets up a specific number of buffers.
	 */
	public void setBuffers(size_t num) @safe nothrow {
		import pixelperfectengine.audio.base.func : resetBuffer;
		buffers.length = num;
		for (size_t i ; i < buffers.length ; i++) {
			buffers[i].length = blockSize;
			resetBuffer(buffers[i]);
		}
	}
	public int getChannels() const @nogc @safe pure nothrow {
		return channels;
	}
	/**
	 * Adds a plugin to the list.
	 * Params:
	 *   md = The audio module to be added. Automatic set-up is done upon addition.
	 *   inBuffs = list of the audio inputs to be added, or null if none.
	 *   inCfg = list of audio input IDs to be used. Must be matched with `inBuffs`
	 *   outBuffs - list of the audio outputs to be added, of null if none.
	 *   outCfg = list of audio output IDs to be used. Must be matched with `outBuffs`
	 */
	public void addModule(AudioModule md, size_t[] inBuffs, ubyte[] inCfg, size_t[] outBuffs, ubyte[] outCfg) nothrow {
		md.moduleSetup(inCfg, outCfg, itrn_sampleRate, blockSize, this);
		moduleList ~= md;
		float*[] buffList0, buffList1;
		buffList0.length = inBuffs.length;
		for (size_t i ; i < inBuffs.length ; i++) {
			buffList0[i] = buffers[inBuffs[i]].ptr;
		}
		buffList1.length = outBuffs.length;
		for (size_t i ; i < outBuffs.length ; i++) {
			buffList1[i] = buffers[outBuffs[i]].ptr;
		}
		inBufferList ~= buffList0;
		outBufferList ~= buffList1;
	}
	public void reset() {
		moduleList.length = 0;
		inBufferList.length = 0;
		outBufferList.length = 0;
		setBuffers(0);
	}
	/**
	 * Runs the audio thread and starts the audio output.
	 */
	public int runAudioThread() @nogc nothrow {
		return outStrm.runAudioThread();
	}
	/**
	 * Stops all audio output.
	 */
	public int suspendAudioThread() {
		return outStrm.suspendAudioThread();
	}
}

/**
 * Thrown on audio initialization errors.
 */
public class AudioInitException : PPEException {
	///
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
	///
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
