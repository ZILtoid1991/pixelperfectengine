module PixelPerfectEngine.audio.base.handler;

/*
 * Copyright (C) 2015-2021, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, audio.base.handler module.
 */

import core.thread.osthread;

import std.conv : to;
import std.string : fromStringz;

import PixelPerfectEngine.system.exc;
import PixelPerfectEngine.audio.base.pluginbase;

import bindbc.sdl.bind.sdlaudio;
import bindbc.sdl.bind.sdlerror : SDL_GetError;

/**
 * Manages and initializes audio devices.
 *
 * Only one instance should be made.
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
		req.callback = &callbacksFromSDL;
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
		} else throw new AudioInitException("No audio devices found!");
	}
	/**
	 * Opens a specific audio device for audio playback by ID, then sets the values for buffer sizes etc.
	 *
	 * Throws an AudioInitException if audio failed to be initialized
	 */
	public void initAudioDevice(int id) {
		if (id >= devices.length) throw new AudioInitException("Audio device not found");
		openedDevice = SDL_OpenAudioDevice(id >= 0 ? devices[id] : null, 0, &req, &given, 
				SDL_AUDIO_ALLOW_FORMAT_CHANGE | SDL_AUDIO_ALLOW_FREQUENCY_CHANGE);
		if (openedDevice < 0) throw new AudioInitException("Audio device couldn't be opened. Error code: " ~ 
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
}
alias CallBackDeleg = void delegate(void* userdata, ubyte* stream, int len) @nogc nothrow;
///Privides a way for delegates to be called from SDL2.
///Must be set up before audio device initialization.
static CallBackDeleg audioCallbackDeleg;
/**
 * A function that handles callbacks from SDL2's audio system.
 */
extern(C) void callbacksFromSDL(void* userdata, ubyte* stream, int len) @nogc nothrow {
	audioCallbackDeleg(userdata, stream, len);
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