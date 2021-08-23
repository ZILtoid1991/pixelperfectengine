# synth layout

* 16 channels consisting of two operators (oscillator + envelop generator) and one extra envelop generator. Channels can be individually paired up for more complex tones and algorithms (12), at the cost of poliphony (8, if every channel is paired)
* Two LFOs, one for pitch control, one for amplitude.
* 4 outputs. One pair for main stereo out, and two individual mono auxiliary outputs for effect send, etc. Each output has a 12db/o low-pass filter to either remove some of the aliasing artifacts, or to even use them for improvised substractive synthesis

# Operator

## Diagram

```
               /|[fbAmp]               
  |-----------<-|-----------------| [fbMode]
  |            \|                  \
  |  |--------------------|         \
  |->|fb    /\            |    o     o
     |     /  \           |    | |\  |
---->|in  -----------  out|----->| >---->
     |          \  /      | [amp]|/   [out_a]
     |           \/       |       |
     |--------------------|       |
        [wavetable]               |
    |------------------|          |
    |      /\___       |          |
    |     /     \      |---->-----|
    |  --------------- |[ADSREnvGen]
    |------------------|
```
## operator controllers

Note: unregistered parameter bank 0 is belonging to operator 0 and bank 1 is belonging to operator 1. Single-byte only parameters only use the top 7 bits of 32 bit control change commands of MIDI2.0.

* `waveform`: Selects a waveform from the 128, externally loaded ones. The wavetable itself is a 16 bit table, with 1024 long waveforms. Controlled by either unregistered parameter 6 (single-byte only), or cc70(0)/cc75(1).
* `atk`: Selects a predefined attack time, and it'll be applied to the envelop generator. Controlled by either unregistered parameter 1 (single-byte only), or cc73(0)/cc78.
* `dec`: Selects a predefined decay time, and it'll be applied to the envelop generator. Controlled by either unregistered parameter 2 (single-byte only), or cc74(0)/cc79.
* `rel`: Selects a predefined release time, and it'll be applied to the envelop generator. Controlled by either unregistered parameter 5 (single-byte only), or cc72(0)/cc77.
* `sus`: Sets the sustain level. Controlled by either unregistered parameter 3, or cc16(0)/cc24(1).
* `susC`: Controls how the envelop will behave during the sustain phase. 0 means the envelop is percussive, the moment the envelop reaches the sustain level it switches to release phase. 1-63 will choose a descending curve, 64 sets the sustain constant 65-127 will choose an ascending curve. Controlled by either unregistered parameter 4 (single-byte only), or by cc81(0)/cc83(1)
* `outLevel`: Controls the output level of the operator. Controlled by either unregistered parameter 0, or cc17(0)/cc25(1)
* `fbAmount`: Controls how much feedback the operator has. Controlled by either unregistered parameter 7, or cc71(0)/cc76(1)
* `opCtrl`: ubyte. If bit 0 is set, feedback will be taken directly from the output of the oscillator, otherwise the envelop generator affected level will be used. If bit 1 is set, then the amplitude LFO will modify the output level of the operator. Bit 2 enables the velocity control of the output level, bit 3 is for the feedback level. Controlled by cc80 on O0, and cc82 on O1.
* `shpA`: Controls the shape of the envolop during the attack phase. 50% creates a mostly linear output. Controlled by either unregistered parameter 10, or cc18(0)/cc26(1).
* `shpR`: Controls the shape of the envolop outside the attack phase. 50% creates a mostly linear output. Controlled by either unregistered parameter 10, or cc19(0)/cc27(1).
* `tuneCor`: Sets the coarse tuning of the oscillator. The most significant 7 bits are on a whoe note basis, with the range of -24 to +103 semitones. The remaining bits tune up or down by a whole semitone. Controlled by unregistered parameter 8, or cc20(0)/cc28(1). Note on MIDI2.0: Control change here have enough precision to take care of fine tuning too.
* `tuneFine`: Sets the fine tuning of the oscillator. Controlled by unregistered parameter 9, or cc21(0)/cc29(1).
* `opCtrl`: Operator control flags. Controlled by unregistered parameter 15. See "Operator control flags" for further info.

Note: cc0 through cc31 are 14 bit controllers if a second control change offsetted by 32 (cc32-63) is sent. 

## Operator control flags

Notation: [bit index in parameter settings]{bit index in the operator itself}

* `FBMode`: Toggles the source of the feedback. L: After envelop generator, H: before envelop generator.[0]{7}
* `FBNeg`: Inverts the feedback if set. [1]{8}
* `ALFOAssign`: Assigns amplitude LFO to the operator output level control. [2]{9}
* `VelOLAssign`: Assigns the velocity control parameter to the operator output level control. [3]{10}
* `VelFBAssign`: Assigns the velocity control parameter to the feedback level control. [4]{11}
* `VelAtkAssign`: Assigns the velocity control parameter to the attack time control. [5]{12}
* `VelSusAssign`: Assigns the velocity control parameter to the sustain level control. [6]{13}
* `VelAtkShp`: Assigns the velocity control parameter to the attack shape control. [7]{14}
* `VelRelShp`: Assigns the velocity control parameter to the release shape control. [8]{15}
* `VelNegative`: Inverts the velocity control for this operator. [9]{16}
* `MWOLAssign`: Assigns the modulation wheel control parameter to the operator output level control. [10]{17}
* `MWFBAssign`: Assigns the modulation wheel control parameter to the feedback control. [11]{18}
* `EEGFBAssign`: Assigns the extra envelope to the feedback control. [12]{19}
* `EGRelAdaptive`: Sets the release rate to be adaptive, and the time to be constant, when uning non-constant sustain levels. [13]{20}

## functions

out = wavetable[((step>>20) + in + fb) & 1023]
out_a = (out * (amp + 1)) >> 12
amp = (ADSREnvGen.shpI(ADSREnvGen.stage == attack ? shpA : shpR) * (outLevel/65536)^2 * 4096
fb = ((fbMode ? out(n-1) : out_a(n-1)) * (fbAmp + 1)) >> 10
fbAmp{if extra ADSREnvGen not assigned to fb} = (fbAmount/256)^2 * 8192
fbAmp{if extra ADSREnvGen is assigned to fb} = (exADSREnvGen.gammaI(ADSREnvGen.stage == attack ? shpAX : shpRX) * (fbAmount/256)^2 * 8192

For each cycle, increment `step` by `rate`, and let it overflow.

Note for operator input: This might be need to be divided by a certain amount, but this will be revealed during testing.

# Channel

A single channel consists of:

* Two operators, each with its own envelop generator
* An extra, assignable envelop generator

## master controls

Registered paramerers 0, 1, and 2 work as in the Midi specification, the rest are unsupported.

Other master controls:

* `vol`: channel volume. Converted to a logarithmic scale. cc07 [m2]
* `bal`: channel balance. cc08 [m2]
* `shpAX`: double, between 0.3 and 3.0. Controls the shape of the extra envelop during the attack curve. cc14 [m2]
* `shpRX`: double, between 0.3 and 3.0. Controls the shape of the extra envelop outside the attack curve. cc15 [m2]
* `atkX`: ubyte, between 0 and 127. Selects a predefined attack time, and it'll be applied to the extra envelope generator. cc85
* `decX`: ubyte, between 0 and 127. Selects a predefined decay time (attack time * 3), and it'll be applied to the extra envelope generator. cc86
* `relX`: ubyte, between 0 and 127. Selects a predefined release time (attack time * 3), and it'll be applied to the extra envelope generator. cc87
* `susX`: uint. Sets the sustain level of the extra envelope. cc12 [m2]
* `susCX`: int. Controls how the EEG will behave in the sustain phase. cc88 [m2]
* `pitchAm`: uint. Sets the amount the EEG can detune the channel (coarse: +63/-64). cc13 [m2] (note on channel combination: only one channel's EEG can affect the pitch of the channel)
* `eegAssign`: ubyte. Bit 0 enables the EEG to modify the feedback loop of O0, bit 1 the feedback loop of O1, bit 2 the channel volume, bit 3 the channel balance, bit 4 the pitch LFO, bit 5 the volume/level LFO, bit 6 both aux send controls. cc89
* `aLFOAssign`: ubyte. If bit 0 is set, then the master volume can be affected by the amplitude LFO. Bit 1 enables this for the channel balance. Bit 2 for aux send levels. cc90
* `aux0Send`: double. Converted to a logarithmic scale. Controls the amount of sound sent to the aux0 output. cc91 [m2]
* `aux1Send`: double. Converted to a logarithmic scale. Controls the amount of sound sent to the aux1 output. cc92 [m2]
* `aLFOamount`: double. Controls how much the amplitude levels will be affected by the amplitude LFO. cc93 [m2]
* `pLFOamount`: double. Controls how much the pitch will be affected by the pitch LFO. cc94 [m2]
* `channelCtrl`: ubyte. Controls the channel. Bit 0 selects an algorithm. Bit 1 and 2 on a secondary channel can combine it with a primary one. cc102
* `velCtrlAssign`: ubyte. Controls what parameters the velocity control can affect. Bit 0 is the amplitude, bit 1 is the pitch amount assignment. cc103.
* `velCtrlAm`: double. Controls how much the velocity should affect the control parameters. cc104 [m2]

## channel combination

By default, the FM synth has two operators per channel, for 16 channels, with each channel being monophonic.

In this mode, each channel has two algorithms:

```
algorithm 0:
[O0]->[O1]

algorithm 1:
[O0]->
[O1]->
```

By combining channels, one can trade poliphony for more complex algorithms:
```
Combination mode 1:

algorithm 00:
[S0]->[S1]->[P0]->[P1]->

algorithm 10:
[S0]\
     ->[P0]->[P1]->
[S1]/

algorithm 01:
[S0]->[S1]->[P0]->
            [P1]->

algorithm 11
[S0]\
     ->[P0]->
[S1]/  [P1]->

Combination mode 2:

algorithm 00:
[S0]->[S1]\
           ->[P1]->
      [P0]/

algorithm 10:
[S0]\
[S1]-->[P1]->
[P0]/

algorithm 01:
          /[P0]->
[S0]->[S1]
          \[P1]->

algorithm 11:
[S0]\ /[P0]->
     -
[S1]/ \[P1]->

combination mode 3:

algorithm 00:
[S0]->[S1]->
[P0]->[P1]->

algorithm 10:
      [S0]->
      [S1]->
[P0]->[P1]->

algorithm 01:
    />[S1]->
[S0]->[P0]->
    \>[P1]->

algorithm 11:
[S0]->
[S1]->
[P0]->
[P1]->
```

# sysex strings

MIDI 1.0 Sysex command `01` enables the setting of global parameters, such as LFO frequencies and waveforms. Command `02 <chnum>` work on both 1.0 and 2.0 implementation, and saves the current preset to the current position. Command `03 <chnum>` will cause the synth to send a single command back to the host, if the channel runs out.

## Control parameters

* 01: LFOp frequency MSB
* 02: LFOp frequency LSB
* 03: LFOp waveform select
* 04: LFOa frequency MSB
* 05: LFOa frequency LSB
* 06: LFOa waveform select
 
For MIDI 2.0, these values can be found on page 16 of any non-registered parameter CC, except that 02, and 05 are invalid, and instead a single 32 bit value can set the LFO frequency.