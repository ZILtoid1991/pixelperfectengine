# Contributing guidelines for PixelPerfectEngine and its subcomponents

## General guidelines.

Follow our code of conduct. Toxic behavior (which includes discriminatory behaviors), bullying, and unwanted advances on other community members are not allowed, and will result with blocking such individuals from further contribution.

People known for doing malicious commits (like purposefully hiding security issues in code) will also be blocked.

Other disallowed behavior include:
* Trolling.
* Trying to steer the project in directions it wasn't planned to go in.
* Bothering the development team with vague ideas.

## Testing

If you use the engine and/or any of its components (editors, etc.) and you find any bugs, or in case of editors, issues with the user experience (hard to use, missing features, etc.), please fill a report in the "Issues" page. If you want to be really awesome, you can: 
* Compile the code yourself in debug mode (see user manual), to then run the program in a debugger (GDB, RemedyBG, etc.) to generate crash reports (a callstack helps a lot). 
* Try to use the editors in unintended ways to hunt for bugs that may crash the program.
* Test the limits of the engine, so either new safety features or bugfixes can be implemented, or the documentation can have a warning about things.

## Documentation

If parts of the code lack documentation, or the documentation is not quality, and you can figure out what it should do, then feel free to do so and issue a pull request.

Rather than just an entirely self-documenting code, one should be more verbose and tell things like what the function, class, or struct actually does, go through a brief about the algorithm it uses, and if possible, credit the person and/or other source of said algorithm.

Due to the unreliable nature of LLMs (including but not limited to: ChatGPT, Copilot, Gemini, LLaMA), and them being trained on both copyrighted text and text with various licenses, we disallow the use of such tools even with heavy editing.

## UX design

If you're a UX designer and notice any issue with our GUI, then feel free to educate us on the topic, or even use our tools (WindowMaker for Concrete, etc) to create better layouts.

If you're interested in long-time commitment, then we can dispatch you specifically to that role.

## Code

By default, unless someone has broken either the contribution guidelines or the code of conduct to a given severity, commiting bugfixes are open for all as long as they're committed to a branch, so potential malicious commitments can be filtered.

If you want to work on new features, please contact with us, so we can dispatch you to a given feature (which could be an auxilliary library), avoiding two people working on the same one.

### Code formatting and naming conventions

Brace style follows the OTLB convention, meaning that statements that are part of a previous one should be on the same line as the previous statement's closing bracket. 4 space wide tabs are also used for block formatting.

```d
if (...) {
	...
} else {
	...
}
try {
	...
} catch (Exception e) {
	...
}
```

Maximum line length is 120 characters, except for single-line comments at the end of a line, which should be used sparingly, and if too long (80 characters or more), broken into multiple lines.

### Code outside of BSL licenses

Engine extensions, such as additional audio modules, can be under other licenses, as long as they're compatible in some way or another. This can be useful when porting code to engine under a different license.

### On AI (Large-Language Model) generated code

Contribution of LLM generated code is forbidden due to the very same issues mentioned in the section of documentation.

## Assets and example games

Due to the nature of this project, assets for testing purposes are needed. Example game projects, either as part of this repository or in some other, are both needed and welcome.

### Guidelines for assets and example games

* When designing any kind of assets for an example game, please be relatively family-friendly and uncontroversial as long as it doesn't impede too much on the gameplay (e.g. we do not ask for games that do not feature any violence). Of course other projects made by the same engine do not need to be adhered by these same rules.
* Example games should be 100% open source (to be included in this repository, it needs the Boost license), with their assets are under either some form of CC license or public domain.
* Example games should be fully documented, so less experienced programmers can learn from it.
* Example games should be relatively simple and small in scale. 
* All pixelart asset should be at scale without any baked in upscaling, as this engine does not need anything like that.
* Fonts should primarily be in the format of Angelcode BMFont. Option for TTF fonts will be added later with hi-res overlays and accessibility options.
* Audio samples generally should be at low sample-rates (exceptions may apply) for that retro sound the engine's audio subsystem was designed for.

### On selling engine-exclusive assets

Engine-exclusive assets, such as:
* maps made in the engine's own format,
* music composed in the M2 format,
* presets, configurations, etc., made for the engine's own audio subsystem;
* scrips and/or code for various purposes,
can be sold for profit, on appropriate channels. The maintainers will not take any responsibility neither for piracy of such materials, or the quality of theirs. The maintainers also don't want to do anything with paid mods.

### On AI (Large-Language Model) generated assets

While not forbidden for personal projects, we forbid the inclusion of any Large-Language Model (including, but not limited to StableDiffusion, MidJourney, SunoAI) generated art assets in any contribution. Reasons being:
* Dislike from artists.
* Often unethical sourcing of training data.
* Unethical business models.
* Ethical concerns about completely automating portion of the human experience.
* Frequent toxicity from the generative AI community towards artists.
* If we wanted to include such assets, we could have done by ourselves, which is the supposed promise of AI.

If such abuse can be proven, the user will be blocked from any further contribution for a very long time.

Algorithm-based generative tools, such as Tilemancer, effects found in most art program, are not constitute as LLMs, and thus are allowed to be used.