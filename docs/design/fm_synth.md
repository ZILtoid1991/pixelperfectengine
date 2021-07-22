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
## local variables

* `wavetable`: the selected wavetable. Each wavetable is 1024 long, and can have values between 0 and 4095. There are 128 wavetables, although many may be all zeroes or duplicates. Wavetables are not preserved during preset dumps, instead it's kept in a `*.wav` file, which the user must preserve alongside with the preset dump file.
* `waveform`: ubyte, between 0 and 127. Selects the waveform for the given operator. Controlled by cc70 on O0, and cc75 on O1.
* `atk`: ubyte, between 0 and 127. Selects a predefined attack time, and it'll be applied to the envelope generator. Controlled by cc73 on O0, and cc78 on O1.
* `dec`: ubyte, between 0 and 127. Selects a predefined decay time (attack time * 3), and it'll be applied to the envelope generator. Controlled by cc74 on O0, and cc79 on O1.
* `rel`: ubyte, between 0 and 127. Selects a predefined release time (attack time * 3), and it'll be applied to the envelope generator. Controlled by cc74 on O0, and cc79 on O1.
* `sus`: uint. Sets the sustain level. Controlled by cc16 on O0, and cc24 on O1. [m2]
* `susC`: int. Controls how the envelope will behave during the sustain phase. Controlled by cc81 on O0, and cc83 on O1.
* `outLevel`: double. Sets the output level of the operator. Converted internally to a logarithmic scale. Controlled by cc17 on O0, and cc25 on O1. [m2]
* `fbAmount`: ubyte, between 0 and 255. Sets the feedback amount of the operator. Converted internally to a logarithmic scale. Controlled by cc71 on O0, and cc76 on O1. [m2]
* `opCtrl`: ubyte. If bit 0 is set, feedback will be taken directly from the output of the oscillator, otherwise the envelope generator affected level will be used. If bit 1 is set, then the amplitude LFO will modify the output level of the operator. Controlled by cc80 on O0, and cc82 on O1.
* `shpA`: double, between 0.3 and 3.0. Controls the shape of the envelope during the attack curve. Controlled by cc18 on O0, and cc 26 on O1. [m2]
* `shpB`: double, between 0.3 and 3.0. controls the shape of the envelope outside of the attack curve. Controlled by cc19 on O0, and cc27 on O1. [m2]
* `tune`: uint. The most significant 7 bit set the amount of seminotes (+103 ; -24), the rest sets the amount of seminote upwards. On MIDI 1.0, cc20 tunes the operator coarsely, cc21 within a seminote, for O0. For O1, cc28 and cc29 do the same. In MIDI 2.0 mode, a single corase tune cc can more precisely tune the oscillators. [m2]

Legend:

* [m2]: Has extended precision with MIDI 2.0

Note: cc0 through cc31 are 14 bit controllers if a second control change offsetted by 32 (cc32-63) is sent. 

## functions

out = wavetable[((step>>20) + in + fb) & 1023]
out_a = (out * (amp + 1)) >> 12
amp = (ADSREnvGen.gammaI(ADSREnvGen.stage == attack ? shpA : shpR) * (outLevel/65536)^2 * 4096
fb = ((fbMode ? out(n-1) : out_a(n-1)) * (fbAmp + 1)) >> 10
fbAmp{if extra ADSREnvGen not assigned to fb} = (fbAmount/256)^2 * 8192
fbAmp{if extra ADSREnvGen is assigned to fb} = (exADSREnvGen.gammaI(ADSREnvGen.stage == attack ? shpAX : shpRX) * (fbAmount/256)^2 * 8192

For each cycle, increment `step` by `rate`, and let it overflow.

Note for operator input: This might be need to be divided by a certain amount, but this will be revealed during testing.

# Channel

A single channel consists of:

* Two operators, each with its own envelope generator
* An extra, assignable envelope generator

## master controls

Registered paramerers 0, 1, and 2 work as in the Midi specification, the rest are unsupported.

Other master controls:

* `vol`: channel volume. Converted to a logarithmic scale. cc07 [m2]
* `bal`: channel balance. cc08 [m2]
* `shpAX`: double, between 0.3 and 3.0. Controls the shape of the extra envelope during the attack curve. cc14 [m2]
* `shpRX`: double, between 0.3 and 3.0. Controls the shape of the extra envelope outside the attack curve. cc15 [m2]
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