# System functions

In the first part, we go over the most important system functions as well as how the folder structure should look like.

# Table of Content

1. Input
2. Screen output
3. Configuration management
4. File handling
5. Other system functions

# Folder structure

Since it's a quite short section, I won't make a separate chapter for it.

* `/bin/` or `/bin-<arch>-<os>`: The folder for all the binary files, including the DLL files being used (SDL2, etc).
Debug symbol files on Windows go there too.
* `/system/`: All engine-essential data go here, which are uncompressed. This include a basic set of fonts, files
containing basic GUI icons, configuration backups, etc. You can even put your company logo there if you want.
* `/lang/`: Localization data, including translated texts, fonts required to display some language's texts, dubbed
speech clips, etc. Can be compressed.

For all other data, there's no standard. For smaller projects, you can use a single `/assets/` folder. For larger 
projects, you want to separate them by type. This might look like this: `/audio/`, `/graphics/`, `/maps/`, etc.