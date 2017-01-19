/*
 * Copyright (C) 2015-2017, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, extbmp.animation module
 */

module PixelPerfectEngine.extbmp.animation;

public struct AnimationData{
	string[] ID;
	int[] duration;

	public void addFrame(string ID, int lenght){
		this.ID ~= ID;
		this.duration ~= lenght;
	}


}

