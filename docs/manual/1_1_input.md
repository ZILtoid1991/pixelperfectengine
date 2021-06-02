# Input Handling

The input handler is probably the most important part of the engine. Without it, you couldn't interact with the game,
and only watch the graphics of the game, and even the most graphics-crazed people would find that boring.

The game controllers that are supported by the engine at the moment are:

* The keyboard. Originally intended for text input, later got a buncs of extra keys to make softwares easier to handle.
Cursor keys were originally intended for navigating, well, the cursors, however they also became quite essential for
gaming until FPSes with mouse look became the standard for PC gaming.

* The mouse. Developed to interact with graphics objects on computers, used widely in strategy, management, puzzle
games, and a must have for all FPS games with mouse look. While you won't be able to develop the latter game genre with
this engine (unless you write your own layers for it), all the others are very possible with it. Also it's mandatory
for the GUI subsystem, and very useful for menus.

* Anything that is interpreted by the OS as a joystick or a game controller. This includes things like wheels too.
However, nowadays the source most likely will be a gamepad, with a directional pad, two analog joysticks, four regular
face buttons, two extra buttons on front, two bumper buttons, and two analog triggers. The engine even can handle force
feedback capable devices.

* (Support in development) The touchscreen. As PDAs got gentrified for businessmen, we ended up with the smaller
smartphones, and the larger tablets, thus making it the most widespread game input device. Often disliked due to how
lazy developers use it, and the quality of the "free" games people often control with it, however it doesn't mean it's
all bad, wasn't executed well, and doesn't have any potential.

# The input package's layour

Found as `PixelPerfectEngine.system.input`. It is taken into multiple subcomponents for easier maintainance and 
readability.

## Types

Found as `PixelPerfectEngine.system.input.types`. Contains various types associated with input lookup, input events,
values, etc.

### KeyModifier

An enumerator containing all possible keyboard modifier keys as flags in a single byte, without duplicates, as they're
not handled. All member names should be obvious, and the `LockKeys` and `All` members should be used for key modifier
ignore flags.

### JoyModifier

In case of joysticks, the `keyMod` portion isn't unused, and instead repurposed to indicate what the ID stands for.

* `Button` simply indicates, that this is a button, and no further action is needed.
* `DPad` indicates that the `keyNum` field stores direction data.
* `Axis` indicates that the `keyNum` field stores the number of the axis.

## Interfaces

Found as `PixelPerfectEngine.system.input.interfaces`. Contains interfaces to enable objects to receive messages from
the `InputHandler` class.

### InputListener

Used to receive general controller input events. Has two functions with mainly the same arguments, but with the 
difference of one having a bool `isPressed`, and one a float `value`.

Argument `id` is the hash value of the human readable string ID used in the config file to identify the key or axis
bindings. It is converted to hash to speed up comparison.

