module pixelperfectengine.audio.base.handler;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.handler module.
 */

import core.thread.osthread;

import std.conv : to;
import std.string : fromStringz;
import std.bitmanip : bitfields;

import pixelperfectengine.system.exc;
import pixelperfectengine.audio.base.modulebase;

import bindbc.sdl.bind.sdlaudio;
import bindbc.sdl.bind.sdlerror : SDL_GetError;
import bindbc.sdl.bind.sdl : SDL_Init, SDL_INIT_AUDIO;

/**
 * Manages and initializes audio devices.
 *
 * Important: Only one instance should be made.
 */
public class AudioDeviceHandler {
	protected const(char)*[]		devices;		///Names of the devices
	protected const(char)*[]		drivers;		///Names of the drivers
	protected SDL_AudioDeviceID		openedDevice;	///The ID of the opened audio device
	protected SDL_AudioSpec			req;			///Requested audio specs
	protected SDL_AudioSpec			given;			///Given audio specs
	/** 
	 * Creates an instance, and detects all drivers.
	 *
	 * slmpFreq: Sampling frequency
	 * channels: Number of channels
	 * buffSize: The size of the buffer in samples
	 *
	 * Throws an AudioInitException if audio is failed to be initialized.
	 */
	public this(int slmpFreq, ubyte channels, ushort buffSize) {
		SDL_Init(SDL_INIT_AUDIO);
		const int nOfAudioDrivers = SDL_GetNumAudioDrivers();
		//deviceNames.length = SDL_GetNumAudioDevices(0);
		if (nOfAudioDrivers > 0) {
			drivers.reserve(nOfAudioDrivers);
			for (int i ; i < nOfAudioDrivers ; i++) {
				drivers ~= SDL_GetAudioDriver(i);
			}
		} else throw new AudioInitException("No audio drivers were found on this system!");
		req.freq = slmpFreq;
		req.format = SDL_AudioFormat.AUDIO_F32;
		req.channels = channels;
		req.samples = buffSize;
		//req.callback = &callbacksFromSDL;
	}
	///Destructor
	~this() {
		SDL_AudioQuit();
	}
	/**
	 * Initializes an audio driver by ID.
	 *
	 * Throws an AudioInitException if audio failed to be initialized.
	 */
	public void initAudioDriver(int id) {
		if (id >= drivers.length) throw new AudioInitException("Audio driver not found!");
		const int audioStatusCode = SDL_AudioInit(id >= 0 ? drivers[id] : null);
		if (audioStatusCode) throw new AudioInitException("Audio driver failed to be initialized. Error code: " ~ 
				to!string(audioStatusCode) ~ " ; SDL Error message: " ~ fromStringz(SDL_GetError()).idup);
		const int nOfAudioDevices = SDL_GetNumAudioDevices(0);
		if (nOfAudioDevices > 0) {
			devices.reserve(nOfAudioDevices);
			for (int i ; i < nOfAudioDevices ; i++) {
				devices ~= SDL_GetAudioDeviceName(i, 0);
			}
		}
	}
	/**
	 * Opens a specific audio device for audio playback by ID, then sets the values for buffer sizes etc.
	 *
	 * Throws an AudioInitException if audio failed to be initialized
	 */
	public void initAudioDevice(int id) {
		//if (id >= devices.length) throw new AudioInitException("Audio device not found");
		openedDevice = SDL_OpenAudioDevice(id >= 0 ? devices[id] : null, 0, &req, &given,  SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
		if (openedDevice == 0) throw new AudioInitException("Audio device couldn't be opened. Error code: " ~ 
				to!string(openedDevice) ~ " ; SDL Error message: " ~ fromStringz(SDL_GetError()).idup);
	}
	/**
	 * Returns an array with the names of the available audio drivers.
	 */
	public string[] getDrivers() @trusted pure nothrow const {
		string[] result;
		result.reserve(drivers.length);
		for (int i ; i < drivers.length ; i++) {
			result ~= fromStringz(drivers[i]).idup;
		}
		return result;
	}
	/**
	 * Return an array with the names of the available audio devices.
	 */
	public string[] getDevices() @trusted pure nothrow const {
		string[] result;
		result.reserve(devices.length);
		for (int i ; i < devices.length ; i++) {
			result ~= fromStringz(devices[i]).idup;
		}
		return result;
	}
	/** 
	 * Returns the ID of the opened audio device.
	 */
	public SDL_AudioDeviceID getAudioDeviceID() @safe @nogc pure nothrow const {
		return openedDevice;
	}
	/**
	 * Returns the available sampling frequency.
	 */
	public int getSamplingFrequency() @nogc @safe pure nothrow const {
		return given.freq;
	}
	/**
	 * Returns the available format.
	 */
	public SDL_AudioFormat getFormat() @nogc @safe pure nothrow const {
		return given.format;
	}
	/**
	 * Returns the number of audio channels.
	 */
	public ubyte getChannels() @nogc @safe pure nothrow const {
		return given.channels;
	}
	/**
	 * Returns the buffer size in units.
	 */
	public int getBufferSize() @nogc @safe pure nothrow const {
		return given.samples;
	}
}
/**
 * Manages all audio modules complete with routing, MIDI2.0, etc.
 */
public class ModuleManager : Thread {
	/**
	 * Output buffer size in samples.
	 *
	 * Must be set upon initialization.
	 */
	protected int			outBufferSize;
	/**
	 * Rendering buffer size in samples, also the length of a single frame.
	 *
	 * Must be less than outBufferSize, and power of two.
	 */
	protected int			bufferSize;
	/**
	 * Number of maximum frames that can be put into the output buffer.
	 */
	protected int			nOfFrames;
	/**
	 * Current audio frame.
	 */
	protected int			currFrame;
	///Pointer to the audio device handler.
	public AudioDeviceHandler	devHandler;
	/**
	 * List of modules.
	 *
	 * Ran in order, should be ordered in such way to ensure that routing is correct, and the modules that need the
	 * input will get some.
	 */
	protected AudioModule[]	moduleList;
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
	 * All buffers must have the same size, defined by the variable `bufferSize`
	 * The first buffers are used for output rendering.
	 */
	protected float[][]		buffers;
	/**
	 * Final output buffer.
	 *
	 * Words are in LRLRLR... order, or similar, depending on number of channels.
	 */
	protected float[]		finalBuffer;
	/** 
	 * Creates an instance of a module handler.
	 *Params:
	 * handler = The AudioDeviceHandler that contains the data about 
	 */
	public this(AudioDeviceHandler handler, int bufferSize) {
		import pixelperfectengine.audio.base.func : resetBuffer;
		devHandler = handler;
		this.bufferSize = bufferSize;
		assert(handler.getBufferSize % bufferSize == 0, "`bufferSize` is not power of 2!");
		nOfFrames = handler.getBufferSize / bufferSize;
		finalBuffer.length = handler.getChannels() * handler.getBufferSize();
		resetBuffer(finalBuffer);
		
		buffers.length = handler.getChannels();
		for (int i ; i < buffers.length ; i++) {
			buffers[i].length = bufferSize;
			resetBuffer(buffers[i]);
		}
		super(&render);
	}
	/**
	 * Puts the output to the final destination.
	 */
	public void render() @nogc nothrow {
		while (currFrame < nOfFrames)
			renderFrame();
		currFrame = 0;
		SDL_QueueAudio(devHandler.getAudioDeviceID(), cast(const void*)finalBuffer.ptr, cast(uint)(finalBuffer.length * 
				float.sizeof));
	}
	/**
	 * Renders a single frame of audio.
	 */
	public void renderFrame() @nogc nothrow {
		import pixelperfectengine.audio.base.func : interleave, resetBuffer;
		if (currFrame >= nOfFrames)
			return;
		foreach (ref key; buffers) {
			resetBuffer(key);
		}
		foreach (size_t i, AudioModule am; moduleList) {
			am.renderFrame(inBufferList[i], outBufferList[i]);
		}
		const size_t offset = currFrame * bufferSize;
		interleave(bufferSize, buffers[0].ptr, buffers[1].ptr, finalBuffer.ptr + offset);
		currFrame++;
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
	public void setBuffers(size_t num) nothrow {
		buffers.length = num;
		for (size_t i ; i < buffers.length ; i++) {
			buffers[i].length = bufferSize;
		}
	}
	/**
	 * Adds a plugin to the list.
	 *Params: 
	 * md = The audio module to be added. Automatic set-up is done upon addition.
	 * inBuffs = list of the audio inputs to be added, or null if none.
	 * inCfg = list of audio input IDs to be used. Must be matched with `inBuffs`
	 * outBuffs - list of the audio outputs to be added, of null if none.
	 * outCfg = list of audio output IDs to be used. Must be matched with `outBuffs`
	 */
	public void addModule(AudioModule md, size_t[] inBuffs, ubyte[] inCfg, size_t[] outBuffs, ubyte[] outCfg) nothrow {
		md.moduleSetup(inCfg, outCfg, devHandler.getSamplingFrequency, bufferSize, this);
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
	
	/**
	 * Locks the manager and all audio modules within it to avoid interference from GC.
	 *
	 * This will however disable any further memory allocation until thread is unlocked.
	 */
	public void lockAudioThread() {
		
	}
	/**
	 * Unlocks the manager and all audio modules within it to allow GC allocation, which is needed for loading, etc.
	 *
	 * Note that this will probably result in the GC regularly stopping the audio thread, resulting in audio glitches,
	 * etc.
	 */
	public void unlockAudioThread() {

	}
}
/+
alias CallBackDeleg = void delegate(void* userdata, ubyte* stream, int len) @nogc nothrow;
///Privides a way for delegates to be called from SDL2.
///Must be set up before audio device initialization.
static CallBackDeleg audioCallbackDeleg;
/**
 * A function that handles callbacks from SDL2's audio system.
 */
extern(C) void callbacksFromSDL(void* userdata, ubyte* stream, int len) @nogc nothrow {
	if (audioCallbackDeleg !is null)
		audioCallbackDeleg(userdata, stream, len);
}+/
/** 
 * Sets up the module manager to be used with SDL2's audio output.
 * Params:
 *   mm = The target module manager.
 */
/+void setupModuleManager(ModuleManager mm) {
	audioCallbackDeleg = &mm.put;

}+/
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
