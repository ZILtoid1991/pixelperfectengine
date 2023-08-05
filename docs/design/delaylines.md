# Delay line layout and introduction

## Single tap layout

```
[tap in]──[FIR]─┬─[MixerOut A/B]─[To mixer]
                │
                └─[FBOut A/B]────[To feedback]
```

## Effects properties

* 2 inputs and outputs
* 2 Delay lines, with each having 4 taps with a 16 element FIR line
* A mixer with 4×2 IIR filters for equalization

## MIDI control change layout

Control change is mainly done on channels 

### Taps

MSB 0 through 7 in the unregistered namespace represent each taps.

* LSB 0 through 15 set the FIR levels.
* LSB 16 through 19 are output Levels, including feedback (LRAB).
* LSB 20 sets the position of the tap.
* LSB 21 disables the tap. (Might result in performance gain).
* LSB 22 disables the FIR. (Might result in performance gain).

MSB 9 has all the EQ. Upper 3 bits of the LSB select the EQ, lower two bits set the given parameters:

* 0 sets the level between -0.5 and 1.0.
* 1 sets the mid frequency between 0 and 20 000 Hz.
* 2 sets the Q value (filter bandwidth).

MSB 10 contain the master values:

* LSB 0 through 3 set the input levels from various inputs of the module into the delay lines.
* LSB 4 through 5 set the master output levels.

# Module config parameters

DelayLines needs to be set up with two extra parameters in the audio config file, something like this:

```s
module "delaylines" "audiofx" 4096 4096
```

The 3rd and the 4th parameters set the length of the delay lines, and must be powers of two.