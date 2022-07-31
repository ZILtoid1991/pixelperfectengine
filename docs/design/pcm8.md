# Synth layout

* 8 sample-based PCM channels capable of decoding 8 bit PCM, 16 bit PCM, mu-Law, A-Law, IMA ADPCM, and Dialogic ADPCM streams.
* Built-in looping function.
* 1 Envelop generator per channel.
* 1 LFO shared between channels, can repurposed as a ring modulation source.

# Sample management

Samples should be loaded from a module setup file, alongside with the sample-key assignment. The procedure is as follows:

1) Specify a \*.wav file to be loaded, alongside with a unique ID, which will be important in accessing the sample later on (zero is reserved).
2) Open up a preset (either an existing or a new one), then select a note assignment in the editor. It should be looking something like `Sample-[note number]_[property]`.
3) First select the sample for the given note number with the `Select` property, by entering the sample ID (one sample can be associated for multiple notes and/or presets).
4) Enter the desired sample rate to the `SlmpFreq` property. This can be either the original sampling frequency, or an altered one to pitch the sample.
5) Properties `LoopBegin` and `LoopEnd` are set to -1 (disabled), but can be set if looping is desired.

At one point, I'll write a built-in macro to make stuff like this easier.

# Channel controllers

|Name           |Number     |Purpose                                                                                             |
|---------------|-----------|----------------------------------------------------------------------------------------------------|
|Volume         |7/39       |Channel volume                                                                                      |
|Balance        |8/40       |Channel balance                                                                                     |
|Aux Send A     |91         |Aux Send A level                                                                                    |
|Aux Send B     |92         |Aux Send B level                                                                                    |
|Attack         |73         |Sets the attack time on the envelop generator                                                       |
|Attack Shape   |14/46      |Controls the shape of the attack phase                                                              |
|Decay          |70         |Sets the decay time on the envelop generator                                                        |
|Sus Ctrl       |71         |Controls the sustain curve of the envelop generator                                                 |
|Sus Level      |9/41       |Controls the sustain level                                                                          |
|Release        |72         |Sets the release time on the envelop generator                                                      |
|Release Shape  |15/47      |Controls the shape of the EG output outside of the attack phase                                     |
|Vel To Level   |20/52      |Velocity to level amount                                                                            |
|Vel To Aux Send|21/53      |Velocity to aux send amount                                                                         |
|Vel to Atk Sh  |22/54      |Velocity to attack shape                                                                            |
|Vel to Rel Sh  |23/55      |Velocity to release shape                                                                           |
|LFO to Vol     |24/56      |LFO to volume amount                                                                                |
|ADSR to Vol    |25/57      |ADSR to volume amount                                                                               |
|ADSR to Detune |26/58      |ADSR to detune amount                                                                               |
|LFO to Detune  |27/59      |Vibrato amount (LFO to detune)                                                                      |
|CutOffOnKeyOff |102        |If set, then sample playback stops on key off immediately                                           |
|Modwheel to LFO|103        |Assigns modwheel to LFO levels                                                                      |
|Panning LFO    |104        |Inverts level on right channel                                                                      |

## Global controllers

|Name           |Number     |Purpose                                                                                             |
|---------------|-----------|----------------------------------------------------------------------------------------------------|
|LPF Left Freq  |2/34       |Low-pass filter frequency, left channel                                                             |
|LPF Left Q     |3/35       |Low-pass filter resonance, left channel                                                             |
|LPF Right Freq |4/36       |Low-pass filter frequency, right channel                                                            |
|LPF Right Q    |5/37       |Low-pass filter resonance, right channel                                                            |
|LPF AuxA Freq  |6/38       |Low-pass filter frequency, Aux channel A                                                            |
|LPF AuxA Q     |7/39       |Low-pass filter resonance, Aux channel A                                                            |
|LPF AuxB Freq  |8/40       |Low-pass filter frequency, Aux channel B                                                            |
|LPF AuxB Q     |9/41       |Low-pass filter resonance, Aux channel B                                                            |
|LFO Freq       |10/42      |LFO frequency (0Hz-20Hz in normal mode, Midi-note + fraction in Ringmod mode)                       |
|LFO PWM        |11/43      |LFO pulse width modulation                                                                          |
|LFO Saw        |102        |Enables the sawtooth output of the LFO                                                              |
|LFO Triangle   |103        |Enables the triangle output of the LFO                                                              |
|LFO Pulse      |104        |Enables the pulse output of the LFO                                                                 |
|LFO Sawpulse   |105        |Enables the sawpulse output of the LFO                                                              |
|LFO Invert     |106        |Inverts the output of the LFO                                                                       |
|LFO Ringmod    |107        |Switches the LFO's frequency range into the audio spectrum, making it usable for ring modulation (might not play well with vibrato)|

# Module-specific SysEx commands

|Code and layout               |Purpose                                                                                          |
|------------------------------|-------------------------------------------------------------------------------------------------|
|20 ch p0 p1 p2 p3[pr d0 d1 d2]|Jumps in the waveform on the channel by restoring a previous codec state (7bit)                  |
|21 ch                         |Dumps the codec state through the MIDI out (7bit)                                                |
|A0 ch p0 p1 p2 p3[pr d0 d1]   |Jumps in the waveform on the channel by restoring a previous codec state (8bit)                  |
|A1 ch                         |Dumps the codec state through the MIDI out (8bit)                                                |

These commands were designed to allow the composer to jump within the sample during playback, which might be useful for breakbeat splicing for certain musical genres (drum & bass, etc.). Since certain formats (ADPCM) require predictor data and a delta, that can be also dumped/supplied.

The format of the codec dump is:

* with 7 bit SysEx commands: 4 bytes of position data (28 bits accessible: should be more than enough), 1 byte of predictor data, 3 bytes of delta data (only 2 bits are used in d0 to get the full 16 bits)
* with 8 bit SysEx commands: 4 bytes of position data (all 32 bits are accessible), 1 byte of predictor data, 2 bytes of delta data
* in any case where an ADPCM codec is not used, predictor and delta can be ditched from the sysex data, and is not sent out during a data dump if not needed.

8 bit jump and restore commands should fit into a single 8 bit SysEx packet even with the codec state and manufacturer code.

Technically, one can supply invalid deltas and predictors to cause glitchy-type sound effects, and there are some basic checks in place to avoid fatal errors.