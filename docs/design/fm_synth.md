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

Unregistered parameter bank 0 and 1 belong to operator controls. Numbers in square brackets mean number of unregistered parameter.

* `Level` [0]: Controls the output level of the operator. Exponential (`y = ²`). 
* `Attack` [1]: Controls the attack time of the operator's attack time.
* `Decay`:
* `SusLevel`:
* `SusCtrl`:
* `Release`:
* `Waveform`:
* `Feedback`:
* `TuneCor`:
* `TuneFine`:
* `ShpA`:
* `ShpR`:
* `VelToLevel`:
* `MWToLevel`:
* `LFOToLevel`:
* `OpCtrl`:
* `VelToFB`:
* `MWToFB`:
* `LFOToFB`:
* `EEGToFB`:
* `VelToShpA`:
* `VelToShpR`:
* `KSLBegin`:
* `KSLAttenOut`:
* `KSLAttenFB`:
* `KSLAttenADSR`:

### Operator control flags

Notation: [bit index in parameter settings]{bit index in the operator itself}

* `FBMode`:
* `FBNeg`:
* `MWNeg`:
* `VelNeg`:
* `EGRelAdaptive`:
* `FixedPitch`:
* `EasyTune`:

## functions

out = wavetable[((step>>20) + (in>>4) + (fb>>3)) & 1023]
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

### registered parameters

### unregistered parameters

* `MasterVol` [0]:
* `Bal` [1]:
* `AuxSLA` [2]:
* `AuxSLB` [3]:
* `EEGDetune` [4]:
* `PLFO` [5]:
* `Attack` [6]:
* `Decay` [7]:
* `SusLevel` [8]:
* `SusCtrl` [9]:
* `Release` [10]:
* `ShpA` [11]:
* `ShpR` [12]:
* `GlobalFB` [13]:
* `ChCtrl` [16]:
* `EEGToLeft` [18]:
* `EEGToRight` [19]:
* `EEGToAuxA` [20]:
* `EEGToAuxB` [21]:
* `LFOToLeft` [22]:
* `LFOToRight` [23]:
* `LFOToAuxA` [24]:
* `LFOToAuxB` [25]:
* `MWToGFB` [26]:
* `VelToGFB` [27]:

#### channel control flags

* `ComboMode` [0-1]:
* `Algorithm` [2]:
* `IndivOutChLev` [3]:
* `LFOPan` [4]:
* `EEGPan` [5]:
* `MWToTrem` [6]:
* `MWToVibr` [7]:
* `MWToAux` [8]:
* `ResetOnKeyOn` [9]:
* `ResetMode` [10]:
* `FBMode` [11]:
* `FBNeg` [12]:

## channel combination

By default, the FM synth has two operators per channel, for 16 channels, with each channel being monophonic.

In this mode, each channel has two algorithms:

```
algorithm 0:
 ┌──────┐
[O0]->[O1]->

algorithm 1:
[O0]->
[O1]->
```

By combining channels, one can trade poliphony for more complex algorithms:
```
Combination mode 1:

algorithm 00:
 ┌──────────────────┐
[S0]->[S1]->[P0]->[P1]->

algorithm 10:
 ┌─────────────┐
[S0]\          │
     ->[P0]->[P1]->
[S1]/

algorithm 01:
 ┌────────────┐
[S0]->[S1]->[P0]->
            [P1]->

algorithm 11
┌────────┐
[S0]\    │
     ->[P0]->
[S1]/  [P1]->

Combination mode 2:

algorithm 00:
 ┌─────────────┐
[S0]->[S1]\    │
           ->[P1]->
      [P0]/

algorithm 10:
 ┌───────┐
[S0]\    │
[S1]-->[P1]->
[P0]/

algorithm 01:
 ┌───────────┐
 │        /[P0]->
[S0]->[S1]
          \[P1]->

algorithm 11:
 ┌───────┐
[S0]\ /[P0]->
     -
[S1]/ \[P1]->

combination mode 3:

algorithm 00:
 ┌──────┐
[S0]->[S1]->
[P0]->[P1]->

algorithm 10:
      [S0]->
      [S1]->
[P0]->[P1]->
 └──────┘

algorithm 01:
 ┌──────┐
 │  />[S1]->
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