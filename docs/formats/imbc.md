# The IMBC format

Intelligent MIDI Bytecode.

## Background and rationale behind creating the IMBC formats

* There's no known MIDI 2.0 file formats.
* Most other music command file formats also lack extensions for creating adaptive soundtracks.

## General guidelines

* Make the format easy to process by the sequencer.
* Make the binary based on RIFF and similar data serialization formats.
* Give it branching capabilities for adaptive soundtracks.
* Create a human readable format similar to Music Markup Language formats.

# Version history

Pre-implementation versions included:
* A human-readable version based on SDLang (dropped in favor of MML-like implementation).
* A more complicated conditional jump system (dropped in favor of a simpler one using various operations to achieve the same effect).

# Magic bytes

Every binary m2 file must begin with `MIDI2.0B`, and a file version identifier word (32 bits, zero for first initial version). Textual m2 files begin with `MIDI2.0 VER 1`, where `1` must be substituted with current version of the file.

# Human-readable format

## General rule

Each line is simply ended with some CR-LF combination the OS use. Readers must make processing OS agnostic.

## Note format

The note describing character sequence consists of 
* a letter (case insensitive), 
* a symbol (either `-` or `#`),
* one or more numbers (-1 octave is symbolized as `00`)

Examples: `c#00`, `d-5`, `A#3`.

## Velocity format

Velocity can be entered as:
* a decimal number,
* a hexadecimal number,
* a letter combination (case insensitive) borrowed from music notation.
 
### Recognized letter combinations

* pppp = 0x00 / 0x/00_00
* ppp = 0x0f / 0x00_ff
* pp = 0x1f / 0x22_ff
* p = 0x2f / 0x44_ff
* mp = 0x3f / 0x66_ff
* mf = 0x4f / 0x88_ff
* f = 0x5f / 0xaa_ff
* ff 0x6f / 0xcc_ff
* fff = 0x75 / 0xee_ff
* ffff = 0x7f / 0xff_ff

## Rhythm format 

The rhythm describing character sequence consists of 
* an optional number to describe tuplets,
* one letter to describe note length,
* one or more dots to describe dotted rhythm.

Multiple rhythms can be added together with the plus (`+`) symbol.

### Recognized letters:
* `w`: whole note.
* `h`: half note.
* `q`: quarter note.
* `o`: eight note.
* `s`: sixteenth note.
* `t`: 32th note.
* `i`: 64th note.
* `x`: 128th note.
* `y`: 256th note.
* `z`: 512th note.
* `u`: 1024th note;

Examples: `w`, `h+s..`, `3q`, `5t.`

Associating it with pitch in macros is done in the following ways:
* A colon is used to directly assign a duration to a pitch: `w:c-4 h.:e-4 h..:g-4`.
* A `~` symbol will assign it for all the notes in the current macro: `~w c-4 e-4 g-4`
 
## Comments

Anything put after a semicolon will be ignored until the end of the line.

## Number formats 

Hexadecimal numbers are designated with an `0x` at the beginning, e.g. `0xff`. All numbers can be decimal separated with an underscore, e.g. `123_456_789`, `0xff_ee_dd_cc`

# Human-readable MIDI commands

Within the human-readable format, MIDI commands should be also described in either human readable format, or with macros, but the user can also describe them with `ump[]` instead. Note can be either a number, or a note descriptor.

## Utility messages

### No operation

`midinoop [gr]`

### JR Timestamp

`timestamp [gr] [data]`

### JR clock

`clock [gr] [data]`

## System Real Time and System Common messages

`sysrt [gr] [status] [MIDI1.0 byte 2] [MIDI1.0 byte 3]`

## Legacy (MIDI1.0) messages

Note: In this mode, the upper nibble of channel numbers will set the group number.

### Note off

`m1_nf [ch] [vel] [note]` 

### Note on

`m1_nn [ch] [vel] [note]`

### Polyphonic Aftertouch

`m1_ppres [ch] [vel] [note]`

### Control change

`m1_cc [ch] [index] [data]`

### Program change

`m1_pc [ch] [program]`

### Channel Aftertouch

`m1_cpres [ch] [data]`

### Pitch bend

`m1_pb [ch] [amount]`

Note: Amount will be automatically separated upon parsing into two 7 bit halfs.

## SysEx (7bit/MIDI1.0)

`m1_sysex [gr] [status] [nr. of bytes] [bytes]...`

## MIDI2.0 messages

Note: In this mode, the upper nibble of channel numbers will set the group number.

### Note off

`nf [ch] [vel] [note] {[attrType]=attrVal}`

### Note on

`nn [ch] [vel] [note] {[attrType]=attrVal}`

### Polyphonic Aftertouch

`ppres [ch] [vel] [note]`

### Registered Per-Note Controller Change

`pccr [ch] [note] [index] [data]`

### Assignable Per-Note Controller Change

`pcca [ch] [note] [index] [data]`

### Per-Note Management Message

`pnoteman [ch] [note] [option]`

### Control change (legacy)

`ccl [ch] [index] [data]`

### Control change (registered)

`ccr [ch] [index] [data]`

### Control change (assignable)

`cc [ch] [index] [data]`

### Relative Control change (registered)

`rccr [ch] [index] [data]`

### Relative Control change (assignable)

`rcc [ch] [index] [data]`

### Program change

`pc [ch] [program] {banknum}`

### Channel Aftertouch

`cpres [ch] [data]`

### Pitch bend

`pb [ch] [amount]`

### Per-note pitch bend

`ppb [ch] [note] [amount]`

## SysEx (8bit/MIDI2.0)

`sysex [gr] [status] [nr. of bytes] [stream ID] [bytes]...`

# Binary chunk layout

All binary data are little endian (starting with least significant byte) within the following rules:
* Each 32 bit MIDI2.0 UMPs and all other are the little endian version of what the MIDI2.0 documentation has.
* Data fields of M2 commands are individually little endian.

## Chunk header

`ID` = 8 bytes, ASCII characters, unused ones padded with nulls.

`length` = 64 bit unsigned integer. Equals with the length of the chunk not counting header and footer.

## Chunk footer

`checksum` = 4 bytes, CRC32 checksum of the chunk data. Not used if chunk length is zero.

# Human readable chunk layout

## Chunk header

`[ChunkID] {ChunkName}`

ChunkID is the same as in the binary format. ChunkName is used to designate chunks if applicable (patterns, etc) for easier human readability.

## Chunk footer

`END`

Chunks are simply closed with an `END`. Chunks must not be cascaded or embedded into each other, for that reason any other block should be closed with an all-lowercase `end`.

# Header format

Identifier: `HEADER`

## Binary layout

* `timeFormatID` = 1 byte. 0 = miliseconds, 1 = microseconds, 2 = hnsecs, 3 = custom period based (whole number), 4 = custom period based (16bit whole + 8 fraction), 5 = custom period based (8bit whole + 16 fraction).
* `timeFormatPeriod` = 3 bytes, unsigned integer, the period of which time format 3/4/5 is based on, zero in all other time formats.
* `timeFormatRes` = 4 bytes, unsigned integer, the resolution of time format 3/4/5.
* `deviceNum` = 2 bytes, number of valid devices excluding the sequencer.
* `maxPattern` = 2 bytes, maximum number of patterns at once.
* `patternNum` = 4 bytes, unsigned integer, total number of patterns.
 
## Human readable format

* `timeFormatID [fm]`: Format can be ms = miliseconds, us = microseconds, hns = hnsecs, fmt3, fmt4, fmt5
* `timeFormatPeriod [int]`: Can be either a decimal or hexadecimal number as long as it's differentiated (see chapter on human readable format). Omitted in ms, us, hns modes.
* `timeFormatRes [int]`: Time format resolution.
* `maxPattern [int]`: Maximum number of patterns at once.

# Other recognized chunks

Note: User can implement custom chunks, but user chunks should be all lowercase letters to avoid collision with official ones. They still should be ended with all capital `END` in human-readable form.

## Patterns

Identifier: `PATTERN`

*Binary layout:* Each pattern begin with a 32 bit identifier, of which only the 24 least significant bits are used as an identifier, the rest are category identifier flags. Then comes the binary data of the commands. The entry point is identified by `0x00_00_00_00`

*Human-readable Layout:*
```
PATTERN [name]
[...]
END
```
The entry point is named `main`.

## Metadata

Identifier: `METADATA`

*Binary Layout:* Contains UTF8 string pairs. Each string pair begins with one identifier length byte, then the text of the identifier, two bytes for the length of the content, then the content. Should be padded to be on the boundary of four bytes.

*Human-readable Layout:*

```
METADATA
[identifier]: "[content]"
[...]
END
```

## Device list

Identifier: `DEVLIST`

*Binary Layout:* Each device entry consists of a 16 bit device ID, a byte for string length, and a UTF8 string. Should be padded to be on the boundary of four bytes.

*Human-readable Layout:*

```
DEVLIST
[devicename]: [devicenumber]
[...]
END
```

## Arrays

Identifier: `ARRAY`

*Binary Layout:* Begins with a 32 bit ID, then 32 bit values after each other.

*Human-readable layout:*

```
ARRAY [name]
[list of values]
[...]
END
```

Creates an array for operations. Empty arrays are invalid, and length is initialized by the number of values present in the array. Can be used to initialize scales, etc.

# Virtual machine implementation

## Registers

For programmability, each pattern can access 128 local and 128 global registers as variables. As of this version, stack and heap allocation will be avoided to avoid allocating data in time-critical situations. First local register starts at 0, the last ends at 127. First global register starts at 128, the last ends at 255. All registers are 32 bits wide.

Registers in human-readable form are notated with an `R`, then two hexadecimal numbers, e.g. `R7F`, `R53, RE0`.

### Local registers

Each pattern has its own register set for math and programmable control operations. Register #127 is the output for all the compare operations the pattern does, the rest of it are as of now general purpose, with registers #120-#126 can be reserved for non-general purpose use. 

#### Compare register

Register #127 (CR) is the target of all compare instruction result.

```
CR = (CR<<1) | (cmpXX is true ? 1 : 0)
```

Every time a compare instruction is being executed, the compare register shifts in a new bit to the lowest position. This enables the user to easily test for multiple conditions with minimal overhead.

### Global registers

To share data between each other, to allow global control of the song, etc., 128 global registers are provided. Registers #247-#255 can be reserved for non-general purpose use.

# Command list

## null command

Bytecode layout:

```
[00]{00|00|00}
```

human-readable format:

```
nullcmd
```

Doesn't do anything. In bytecode, the word must be set to all zeroes

## wait command

Bytecode layout:

```
[01]{24 bits of time value}
```
or
```
[02]{24 least significant bits of time value}{32 most significant bits of time value}
```

Human-readable format:

```
wait {number of tics in time format}
```
or
```
wait {rhythm code}
```

Makes the sequencer wait between chains of commands by the given amount. Type of amount is set by the header in bytecode format, or a rhythm code set to the current pattern's rhythm.

This command have two different bytecodes in case a single 24 bit wait time isn't enough in certain cases.

## emit command

Bytecode layout:

```
[03]{Amount: 8 bits}{Device: 16 bits}
```

Human-readable format:

```
[[DeviceID]]: [MIDI command in one line]
```

Emits a given amount of words of MIDI data to the targeted device. If more needed, then more must be chained together. One command ideally should target a single device. Device 65535 is the sequencer, and can be used for things like settings. In human-readable form, each MIDI command is translated to a human-readable format (see chapter on human-readable format).

In human-readable form, device ID is always between brackets, and either is a standard decimal or hexadecimal number, or a name.

## Conditional jump command

Bytecode layout:
```
[04]{condition code: 8 bits}[aux byte A, aux byte B]
{Condition mask: 32 bits}
{jump amount: 32 bits signed integer}
```

Human-readable format:
```
jmpXX [condition mask] [position label]
```

If the condition is true to local register #127 (which is compare code target), then the sequencer jumps forward or backward by the given amount. In human readable form, position labels are used instead. Note: macros for `if-elseif-else` do exist

### Condition codes 

* 0x00/nc: Jump always.
* 0x01/eq: Jump if equal with CR with condition mask.
* 0x02/ne: Jump if not equal CR with condition mask.
* 0x03/sh: Jump if at least one bit is high in CR from condition mask.
* 0x04/op: Jump if all bits are opposite between CR and condition mask.
 
## Inject pattern in parallel

Bytecode layout:
```
[05]{Pattern ID: 24 bits}
```
Human-readable form:
```
chain-par [patternName]
```

Injects a pattern in parallel to the main song data. Pattern cannot chain itself into the the song, and will be ignored.

## Inject pattern in series

Bytecode layout:
```
[06]{Pattern ID: 24 bits}
```
Human readable form:
```
chain-ser [patternName]
```

Injects a pattern in series into the main song data: executes the referenced pattern, then returns to the current position once finished. If used to refer the current pattern, it'll simply reset it.

## Math operations on registers

Bytecode layout:
```
[Op]{RA}{RB}{RD}
```
Human-readable form:
```
[oper] [RA] [RB] [RD]
```

Does math or logic operations on registers. Note: RB is used as an intermediate value for binary shifts

### Possible operations:

* 07/add: RA + RB = RD
* 08/sub: RA - RB = RD
* 09/mul: RA * RB = RD
* 0a/div: RA / RB = RD
* 0b/mod: RA % RB = RD
* 0c/and: RA & RB = RD
* 0d/or: RA | RB = RD
* 0e/xor: RA ^ RB = RD
* 0f/not: ~RA = RD
* 10/lshi: RA<<[RB] = RD
* 11/rshi: RA>>[RB] = RD
* 12/rasi: RA>>>[RB] = RD
* 13/adds: RA + RB = RD (signed)
* 14/subs: RA - RB = RD (signed)
* 15/muls: RA * RB = RD (signed)
* 16/divs: RA / RB = RD (signed)
* 17/lsh: RA<<RB = RD
* 18/rsh: RA>>RB = RD
* 19/ras: RA>>>RB = RD
* 1a/mov: RA = RD
* 1b/satadd: Saturated add
* 1c/satsub: Saturated subtract
* 1d/satmul: Saturated multiply
* 1e/satadds: Signed saturated add
* 1f/satsubs: Signed saturated subtract
* 20/satmuls: Signed saturated multiply
 
## Compare operation

Bytecode layout:
```
[40]{cc}{RA}{RB}
```
Human-readable form:
```
cmpXX RA RB
```

Compares two registers, then shifts a bit into CR to the least significant position, 1 if true, 0 otherwise.

### Condition codes

* 01/eq: RA == RB
* 02/ne: RA != RB
* 03/gt: RA > RB
* 04/ge: RA >= RB
* 05/lt: RA < RB
* 06/le: RA <= RB
* 07/ze: RA == 0
* 08/nz: RA != 0
* 09/ng: RA < 0
* 0a/po: RA > 0
* 0b/sgt: RA > RB (signed)
* 0c/sge: RA >= RB (signed)
* 0d/slt: RA < RB (signed)
* 0e/sle: RA <= RB (signed)

## Abandon current pattern for another one

Bytecode layout:
```
[41]{Pattern ID: 24 bits}
```
Human readable form:
```
chain [patternName]
```

Referenced pattern will be played instead of the current one, with no returning.

## Emit MIDI2.0 command with data from register

Bytecode layout:
```
[42]{Register data source: 8 bits}{Device: 16 bits}{Register note or identifier source: 8 bits}{Channel register identifier: 8 bits}{aux register: 8 bits}{4 bits padding}{D}{N}{C}{A}{8 bytes of MIDI 2.0 data}
```
Human readable form:
```
$[[deviceID]]: [MIDI2.0 command with register number in note, index, data, or channel fields]
```

Sends a single 64bit MIDI2.0 command, with the data, note, and/or index data being sourced from one or two registers. At the very end, there's 4 bits which signal which registers are currently being used.

## Position marker

Bytecode layout:
```
[48]{Position ID: 24 bits}
```
Human readable form:
```
marker [position ID: int]
```

Position marker. Normally, looping should be done through the programming of the file itself, but there might be situations, when this is not possible, or the application needs to jump immediately to a given position in the song. Care should be given for the virtual machine's state itself.

Could be also useful to notify the sequencer host when a marker has been reached by the song.

## Transposing

Bytecode layout:
```
[49]{group/channel: 8 bits}{device ID: 16 bits}{key/mode id: 8 bits}{amount: signed 8 bits/register num}{immediate/register toggle: 1 bit}{reset: 1 bit}{channels exception: 1 bit}{range exception: 1 bit}{range from/to toggle: 1bit}{unused: 11 bits}
```
Human readable form:
```
trnsps [device ID] [key/mode id] [amount: number or register]
;or
trnsps [device ID] reset
```

Sets the transposing for a channel of a device on all note commands, or clears it if the reset bit is high.

## Array operations

Bytecode layout:
```
[4a]{array opcode: 8 bits}{target register: 8 bits}{index register: 8 bits}|{array ID: 32 bits}
```
Human readable form:
```
[arrayOp] [target register] [index register] [array name]
```
### Array opcodes:

* [01]/arrayread: reads array, index turns around.
* [02]/arraywrite: writes array, index turns around.
* [03]/arrayreadsat: reads array, index saturates.
* [04]/arraywritesat: writes array, index saturates.
* [05]/arraylength: stores array length in target register.

## Control command

Bytecode layout:
```
[f0]{command type: 8 bits}{command code: 16 bits} {Arbitrary amount of data depending on the former one}
```
Human readable form:
```
ctrl [rest]
```

Control commands are used to control the processing of the file in real time.

### Command types

#### Set register

`ctrl setReg [Register] [Data to be written to register]`

`0xF0 0x01 [register number: 8 bits] [padding: 8 bits] [data to be written to register 32 bits]`

`0x01`/`setReg` will set the register value specified by command code

#### Sync for external chain

`ctrl syncXC [sync flags as hexanumeric data]`

`0xF0 0x02 [sync flags: 16 bits]`

`0x02`/`syncXC` tells the sequencer that it's okay to process synchronized (external) pattern branching commands with the given flags.

## Display command

Bytecode layout:
```
[ff]{command type: 8 bits}{command code: 16 bits} {Arbitrary amount of data depending on the former one}
```
Human readable form:
```
display [rest]
```

Display commands are mostly play significance in displaying stuff in editors, but some of them are play great significance in the human readable form.

### Note on conditional jump commands

Generally, the text parser doesn't do any processing, as certain things like external meddling with the song globals is not present during parsing, and as such conditional jumps are ignored. One must not use display commands to change things like speed on condition, and instead control commands should be used.

### Command types

#### Display value setting

`0x01`/`setVal` and `0x02`/`setVal64` sets a given value. These commands have 32 and 64 bit data following them respectively.

Currently recognized 32 bit command codes:

* `0x00_01`/`BPM`: Sets the BPM of the current pattern. It's a 32 bit floating point value.
* `0x00_02`/`timeSignature`: Sets the time signature. It's two 16 bit unsigned integers.
* `0x00_03`/`clef`: Sets the clef for the supplied channel and device. It's a 16 bit unsigned integer (device ID), and two 8 bit unsigned integers (channel number and clef ID)
* `0x00_04`/`keySignature`: Sets the key for the supplied channel and device. It's a 16 bit unsigned integer (device ID), and two 8 bit unsigned integers (channel number and key ID)

#### Loop unroll

`0x03`/`0x04`/`loopUnroll` tells the display to unroll the following loop a given amount of times. `0x03` uses only the 16 bit field. `0x04` stores the 16 least significant bits in the 16 bit field, and stores the most significant 32 bit in a new word.

#### Text displays

Command type codes 0xF0 through 0xFE are reserved for string displays, and 0xFF is used for continuation of the previous block if more than 64kB of text is needed, and multiple ones can be chained together. Data must be aligned to 32 bit, with padding with zeros.

Currently recognized text tags are:

* `0xF0`/`strCue`: Cue text.
* `0xF1`/`strNotation`: Notation text.
* `0xF2`/`strLyrics`: Lyrics text.

# Macros

Macros are shorthand for complex commands and MIDI commands, and is only present in human readable form. Once translated, they'll be replaced with the appropriate commands instead.

## Note playback

```
note [ch] [vel] [note and rhythm notations]
note_adv [ch] [vel] [note and rhythm notations]
```

MIDI note, and with `note_adv`, optionally `wait` command macro. If needed, multiple notes can be grouped together on a single macro, separated with space. `note_adv` also inserts `wait` commands equal with the longest note, while also inserting note off commands.

## Branching

```
if [condition list]
    [...]
elseif [condition list]     ;this is optional
    [...]
else                        ;this is optional
    [...]
end
```

Compile into numerous compare and jump statements.

## Position labels

```
@[name]:
```

Labels a position for the `jmpXX` instruction.

## Loops

```
while [condition list]
    [...]
end
```

Loops until the condition is true (checks at entry point).

```
do
    [...]
until [condition list]
```

Loops until the condition is true (checks at endpoint).

# Error and hazard handling strategies
