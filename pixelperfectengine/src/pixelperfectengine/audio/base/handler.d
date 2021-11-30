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
import pixelperfectengine.audio.base.modulebase;

/+import bindbc.sdl.bind.sdlaudio;
import bindbc.sdl.bind.sdlerror : SDL_GetError;
import bindbc.sdl.bind.sdl : SDL_Init, SDL_INIT_AUDIO;+/

import soundio;

/**
 * Manages and initializes audio devices.
 *
 * Important: Only one instance should be made.
 */
public class AudioDeviceHandler {
	protected SoundIoDevice*[]		outDevices;		///Contains the names of the output devices
	protected SoundIo*				context;		///Context for libsoundio
	protected SoundIoDevice*		openedDevice;	///The device that is being used for audio input/output
	SoundIoOutStream*				outStream;		///The opened output stream.
	protected int					channelLayout;	///Requested channel layout
	protected int					slmpFreq;		///Requested/given sampling frequency
	protected int					frameSize;		///Requested/given buffer base size / frame length (in samples)
	protected int					nOfFrames;		///Requested/given number of frames before they get sent to the output
	/** 
	 * Creates an instance, and detects all drivers.
	 *Params: 
	 * slmpFreq: Requested sampling frequency. If not available, a nearby will be used instead.
	 * channels: Number of channels
	 * buffSize: The size of the buffer in samples
	 *
	 * Throws an AudioInitException if audio is failed to be initialized.
	 */
	public this(int channelLayout, int slmpFreq, int frameSize, int nOfFrames) {
		context = soundio_create();
		if (!context) throw new AudioInitException("No enough memory to initialize audio!", SoundIoError.NoMem);
		this.channelLayout = channelLayout;
		this.slmpFreq = slmpFreq;
		this.frameSize = frameSize;
		this.nOfFrames = nOfFrames;
		//req.callback = &callbacksFromSDL;
	}
	///Destructor
	~this() {
		soundio_outstream_destroy(outStream);
		soundio_destroy(context);
	}
	/**
	 * Initializes an audio driver by ID.
	 *
	 * Throws an AudioInitException if audio failed to be initialized.
	 */
	public void initAudioDriver(SoundIoBackend backend) {
		int error = soundio_connect_backend(context, backend);
		if (error) throw new AudioInitException("Could not connect to audio backend!", cast(SoundIoError)error);

		outDevices.length = soundio_output_device_count(context);
		for (int i ; i < outDevices.length ; i++) {
			outDevices[i] = soundio_get_output_device(context, i);
		}
	}
	/**
	 * Opens a specific audio device for audio playback by ID, then sets the values for buffer sizes etc.
	 *
	 * Throws an AudioInitException if audio failed to be initialized
	 */
	public void initAudioDevice(int id) {
		if (id = -1) id = soundio_default_output_device_index(context);
		if (soundio_device_supports_format(outDevices[id], SoundIoFormatFloat32NE) && 
				soundio_device_supports_layout(outDevices[id], soundio_channel_layout_get_builtin(channelLayout)) {
			if (!soundio_device_supports_sample_rate(outDevices[id], slmpFreq)) 
				slmpFreq = soundio_device_nearest_sample_rate(outDevices[id], slmpFreq);
			outStream = soundio_outstream_create(outDevices[id]);
			outStream.sample_rate = slmpFreq;
			outStream.layout = soundio_channel_layout_get_builtin(channelLayout);
			
		} else throw new AudioInitException("Audio format not supported!");
	}
	/**
	 * Return an array with the names of the available audio devices.
	 */
	public string[] getDevices() @trusted pure nothrow const {
		string[] result;
		result.length = outDevices.length;
		for (int i ; i < outDevices.length ; i++) {
			if (outDevices[i])
				result[i] = fromStringz(outDevices[i].name).idup;
		}
		return result;
	}
	/**
	 * Returns the available sampling frequency.
	 */
	public int getSamplingFrequency() @nogc @safe pure nothrow const {
		return slmpFreq;
	}
	/**
	 * Returns the number of audio channels.
	 */
	public int getChannels() @nogc @safe pure nothrow const {
		return given.channels;
	}
	/**
	 * Returns the buffer size in units.
	 */
	public size_t getBufferSize() @nogc @safe pure nothrow const {
		return frameSize * nOfFrames;
	}
}
/**
 * Manages all audio modules complete with routing, MIDI2.0, etc.
 */
public class ModuleManager {
	protected int			bufferSize;		///Rendering buffer size in samples, also the length of a single frame.
	protected int			nOfFrames;		///Number of maximum frames that can be put into the output buffer.
	protected int			currFrame;		///Current audio frame.
	protected uint			statusFlags;	///Status flags of the module manager.
	protected TickDuration	timeStamp;		///Timestamp that is used for scheduling the audio thread.
	protected const TickDuration	timeDelta;///Amount of time that the buffer can hold.
	protected ThreadID		threadID;		///Low-level thread ID.
	/** 
	 * Status flags for the module manager.
	 */
	public enum Flags {
		IsRunning			=	1<<0,		///Set if thread is running.
		BufferUnderrunError	=	1<<16,		///Set if a buffer underrun error have been occured.
		AudioQueueError		=	1<<17,		///Set if the SDL_QueueAudio function returns with an error code.
	}
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
	 * handler = The AudioDeviceHandler that contains the data about the audio device.
	 * bufferSize = The size of the buffer in samples.
	 * nOfFrames = The number of frames before they get queued to the audio device.
	 */
	public this(AudioDeviceHandler handler, int bufferSize, int nOfFrames) {
		import pixelperfectengine.audio.base.func : resetBuffer;
		devHandler = handler;
		this.bufferSize = bufferSize;
		//assert(handler.getBufferSize % bufferSize == 0, "`bufferSize` is not power of 2!");
		//nOfFrames = handler.getBufferSize / bufferSize;
		this.nOfFrames = nOfFrames;
		finalBuffer.length = handler.getChannels() * bufferSize * nOfFrames;
		resetBuffer(finalBuffer);
		
		const real td = (1.0 / handler.getSamplingFrequency()) * bufferSize * nOfFrames;
		timeDelta = TickDuration.from!"usecs"(cast(long)(td * 1_000_000));

		buffers.length = handler.getChannels();
		for (int i ; i < buffers.length ; i++) {
			buffers[i].length = bufferSize;
			resetBuffer(buffers[i]);
		}
		//super(&render);
	}
	/** 
	 * Renders audio to the
	 */
	protected void render(SoundIoOutStream* stream, int frameCountMin, int frameCountMax) @nogc nothrow {
		import pixelperfectengine.system.etc : clamp;

	}
	/+
	/**
	 * Runs the audio thread.
	 */
	protected void run() @nogc nothrow {
		import pixelperfectengine.audio.base.func : interleave, resetBuffer;
		statusFlags = Flags.IsRunning;	//reset status flags
		while (statusFlags & Flags.IsRunning) {
			/+if (SDL_QueueAudio(devHandler.getAudioDeviceID(), cast(const void*)finalBuffer.ptr, cast(uint)(finalBuffer.length * 
					float.sizeof))) statusFlags |= Flags.AudioQueueError;+/
			while (currFrame < nOfFrames) {
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
			currFrame = 0;
			//Put thread to sleep
			TickDuration newTimeStamp = TickDuration.currSystemTick();
			if (newTimeStamp > timeStamp + timeDelta)
				statusFlags |= Flags.BufferUnderrunError;
			else
				Thread.sleep(cast(Duration)(timeDelta - (newTimeStamp - timeStamp)));
			timeStamp = TickDuration.currSystemTick();
		}
	}+/
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
			buffers[i].length = bufferSize;
			resetBuffer(buffers[i]);
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
	 * 
	 */
	public void runAudioThread() @nogc nothrow {
		
	}
	/**
	 * Stops all audio output.
	 * 
	 */
	public uint suspendAudioThread() {
		
	}
}
package static ModuleManager audioOutput;
/** 
 * Called by libsoundio when the list of devices change, then it sets a global parameter to indicate that.
 */
extern(C) @nogc nothrow void callback_OnDevicesChange(SoundIo* context) {

}
/** 
 * Called by libsoundio when the backend disconnects, then it sets a global parameter to indicate that.
 */
extern(C) @nogc nothrow void callback_OnBackendDisconnect(SoundIo* context, int err) {

}
/** 
 * Called by libsoundio every time when audio data is needed.
 */
extern(C) @nogc nothrow void callback_OnWriteRequest(SoundIoOutStream* stream, int frameCountMin, int frameCountMax) {
	audioOutput.render(stream, frameCountMin, frameCountMax);
}
/**
 * Thrown on audio initialization errors.
 */
public class AudioInitException : PPEException {
	/// Errorcode from libsoundIO
	SoundIoError		errorCode;
	///
	@nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
	///
	@nogc @safe pure nothrow this(string msg, SoundIoError errorCode, string file = __FILE__, size_t line = __LINE__, 
			Throwable nextInChain = null)
    {
		this.errorCode = errorCode;
        super(msg ~ fromStringz(soundio_strerror(errorCode)).idup, file, line, nextInChain);
    }
	///
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}
