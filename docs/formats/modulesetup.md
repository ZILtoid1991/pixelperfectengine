# Introduction to Audio Module Setup Files

## What is an "audio module"?

An audio module within the PixelPerfectEngine ecosystem is similar to plugins in DAWs, with the following differences:

* Audio modules by default don't have any GUI. Certain editor suites might have them in the future for certain modules,
for easier setup and configuration by more ordinary musicians (ones without programming knowledge), but by default,
they're not coded directly into the module.
* Optimization for performance and simplicity. While audio quality is still important, there might be certain 
sacrifices made for performance gains and easier maintance over functions or minor artifacts.
* Due to this reason, many instrument modules don't have polyphony capability by their own, instead the composer must
distribute the notes manually across multiple channels. This also eliminates any errors caused by uncertain scenarios.
* Hardcoding. Since there's not too much to gain by making each module its own dynamic link library besides a smaller
executable, it won't be done.

Instrument-type audio modules can create music and various sound effects on the fly, while effect-type audio modules
can alter their outputs. Streaming-types will be used in the future to stream audio data from disk, network, etc.

## What is an "audio module setup file"?

To configure routings of audio modules, recall their parameters, and load samples into them, a special file format
based on SDLang have been developed for this purpose.

# Metadata

All metadata goes into the root tag `Meta`. Not used by the setup process, but has some standardized elements.

# Module

The `Module` root tag contains module configuration information, including preset data.

```s
module "QM816" "fmsynth" {...}
```

Modules can be created by condition if needed. Name should only contain latin letters (either upper or lowercase), 
numbers, or the `_` character.

## Sample loading

To load a sample into the module, just simply use:

```s
loadSample "drum.wav" 56 dpk="../audio/instruments.dpk"
```

Where the first parameter is the filename in string format (can be unicode), the second parameter is the sample ID in 
unsigned 32 bit integer format, and the `dpk` optional attribute tells if the file is in a datapak file and where it
can be found.

## Preset recall

To recall preset parameters, just simply use:

```s
presetRecall 81 name="something" {
    "level" 1.0
    87923045L 0.56
    ...
}
```

Where the first parameters in the nameless tags are the parameter identifiers, and the second parameters are the values 
themselves (int, long, bool, double, and string are allowed). Usually preset identifiers work something like this:

* bits 0-6: preset number
* bits 7-20: bank number

Presets can be named if one chooses so.

# Audio routing setup

Every input or output can be only routed to one node, but a single node can be read or be written by multiple modules.

The routing works as such:

```s
route "fmsynth:mainL" "outputL"
route "fmsynth:mainR" "outputR"
route "fmsynth:auxSendA" "chorus:inputL"
node "reverbRouting" {
    input {
        "fmsynth:auxSendB"
        "sampler:auxSendB"
    }
    output {
        "reverb:inputL"
        "reverb:inputR"
    }
}
```

Where the first string is the source, and the second one is the destination. Naming is as such: 
`"[modulename]:[portname]"`

Tag "route" just simply connects a module's output to a main output , while "node" creates a node with multiple inputs
and outputs.

Conditional routing can be set if needed.

# MIDI track routing

Especially due to the lack of implemented MIDI 2.0 file formats, multiple-track MIDI files must be used, and we must 
tell the program how to route the sequencer.

```s
midiTrack 0 "fmsynth"
midiTrack 1 "sampler" port=5
...
```

The "port" attribute sets the MIDI 2.0 port (default is 0).

# Condition codes

The following condition codes exist:
* `ifNodeExists`
* `ifNodeNotExists`
* `ifHeadphones`
* `ifSampleRate`
* `ifSampleRateMin`
* `ifSampleRateMax`

## Example use

```s
module "Reverb" ifNodeExists="rearL&rearR" {
    loadSample "hall44.wav" 1 ifSampleRate=44100
    loadSample "room44.wav" 2 ifSampleRate=44100
    loadSample "hall48.wav" 1 ifSampleRate=48000
    loadSample "room48.wav" 2 ifSampleRate=48000
}
route "Reverb:auxSendB" "Reverb:inL" ifNodeExists="rearL&rearR"
route "Reverb:auxSendB" "Reverb:inR" ifNodeExists="rearL&rearR"
route "Reverb:outL" "Reverb:rearL" ifNodeExists="rearL&rearR"
route "Reverb:outR" "Reverb:rearR" ifNodeExists="rearL&rearR"
```
