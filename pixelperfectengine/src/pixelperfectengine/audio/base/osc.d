module pixelperfectengine.audio.base.osc;


/** 
 * Implements an oscillator base.
 */
public abstract class Oscillator {
    protected float _frequency;     ///The current frequency of the oscillator
    protected int _slmpFreq;        ///Sampling frequency of the output
    /** 
     * Returns the current output frequency of the oscillator.
     */
    public float frequency() @nogc @safe pure nothrow const {
        return _frequency;
    }
    /**
     * Sets the new frequency of the oscillator, while also changing its internal state.
     */
    public abstract float frequency(float val) @nogc @safe pure nothrow;
    /**
     * Generates an output based on the oscillator's internal states.
     */
    public abstract void generate(int[] output) @nogc nothrow;
}