module pixelperfectengine.audio.modules.delaylines;

import pixelperfectengine.audio.base.modulebase;
import pixelperfectengine.audio.base.types;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.func;
import pixelperfectengine.audio.base.envgen;
import pixelperfectengine.audio.base.osc;
import pixelperfectengine.system.etc : isPowerOf2;

import midi2.types.structs;
import midi2.types.enums;

public class DelayLines : AudioModule {
    protected float[]           priDelayLine;
    protected float[]           secDelayLine;
    protected MultiTapOsc[4]    osc;

    public this(size_t priLen, size_t secLen) {
        assert(isPowerOf2(priLen));
        assert(isPowerOf2(secLen) || !secLen);
        info.nOfAudioInput = 2;
		info.nOfAudioOutput = 2;
        info.inputChNames = ["mainL", "mainR"];
		info.outputChNames = ["mainL", "mainR"];
		info.hasMidiIn = true;
        priDelayLine.length = priLen;
        secDelayLine.length = secLen;
        resetBuffer(priDelayLine);
        resetBuffer(secDelayLine);
    }

    override public void midiReceive(UMP data0, uint data1 = 0, uint data2 = 0, uint data3 = 0) @nogc nothrow {
        
    }

    override public void renderFrame(float*[] input, float*[] output) @nogc nothrow {
        
    }

    override public int waveformDataReceive(uint id, ubyte[] rawData, WaveFormat format) nothrow {
        return int.init; // TODO: implement
    }

    override public int writeParam_int(uint presetID, uint paramID, int value) nothrow {
        return int.init; // TODO: implement
    }

    override public int writeParam_long(uint presetID, uint paramID, long value) nothrow {
        return int.init; // TODO: implement
    }

    override public int writeParam_double(uint presetID, uint paramID, double value) nothrow {
        return int.init; // TODO: implement
    }

    override public int writeParam_string(uint presetID, uint paramID, string value) nothrow {
        return int.init; // TODO: implement
    }

    override public MValue[] getParameters() nothrow {
        return null; // TODO: implement
    }

    override public int readParam_int(uint presetID, uint paramID) nothrow {
        return int.init; // TODO: implement
    }

    override public long readParam_long(uint presetID, uint paramID) nothrow {
        return long.init; // TODO: implement
    }

    override public double readParam_double(uint presetID, uint paramID) nothrow {
        return double.init; // TODO: implement
    }

    override public string readParam_string(uint presetID, uint paramID) nothrow {
        return string.init; // TODO: implement
    }
}