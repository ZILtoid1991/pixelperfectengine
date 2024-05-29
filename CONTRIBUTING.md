# Contributing guidelines for PixelPerfectEngine and its subcomponents

## Testing

If you use the engine and/or any of its components (editors, etc.) and you find any bugs, or in case of editors, issues with the user experience (hard to use, missing features, etc.), please fill a report in the "Issues" page. If you want to be really awesome, you can: 
* Compile the code yourself in debug mode (see user manual), to then run the program in a debugger (GDB, RemedyBG, etc.) to generate crash reports (a callstack helps a lot). 
* Try to use the editors in unintended ways to hunt for bugs that may crash the program.
* Test the limits of the engine, so documentation can be updated accordingly.

## Documentation

If parts of the code lack documentation, or the documentation is not quality, and you can figure out what it should do, then feel free to do so and issue a pull request.

Rather than just an entirely self-documenting code, one should be more verbose and tell things like what the function, class, or struct actually does, go through a brief about the algorithm it uses, and if possible, credit the person and/or other source of said algorithm.

Due to the unreliable nature of LLMs (including but not limited to: ChatGPT, Copilot, llama), and them being trained on both copyrighted text and text with varous licenses, we disallow the use of such tools even with heavy editing.   

## Assets