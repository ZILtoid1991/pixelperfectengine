module pixelperfectengine.audio.base.osc;


/** 
 * Implements an oscillator base.
 */
public abstract class Oscillator {
    protected float _frequency;     ///The current frequency of the oscillator
    protected int _slmpFreq;        ///Sampling frequency of the output
    /** 
     * Returns the sampling frequency set in this oscillator.
     */
    public int slmpFreq() @nogc @safe pure nothrow const {
        return _slmpFreq;
    }
    /** 
     * Sets the sampling frequency of the oscillator.
     * In devived classes, this might also change the internal state of the oscillator.
     */
    public int slmpFreq(int val) @nogc @safe pure nothrow {
        return _slmpFreq = val;
    }
    /** 
     * Returns the current output frequency of the oscillator.
     */
    public float frequency() @nogc @safe pure nothrow const {
        return _frequency;
    }
    /**
     * Sets the new frequency of the oscillator.
     * In devived classes, this might also change the internal state of the oscillator.
     */
    public float frequency(float val) @nogc @safe pure nothrow {
        return _frequency = val;
    }

    /**
     * Generates an output based on the oscillator's internal states.
     */
    public abstract void generate(float[] output) @nogc nothrow;
}
class PulseGen : Oscillator {
    protected double        stepRate;
    protected double        position;
    protected double        pulseWidth;
    /**
     * Generates an output based on the oscillator's internal states.
     */
    public override void generate(float[] output) @nogc nothrow {
        for (size_t i ; i < output.length ; i++) {
            output[i] = position > pulseWidth ? -1 : 1;
            position += stepRate;
            position = position >= 1 ? 0 : position;
        }
    }
}