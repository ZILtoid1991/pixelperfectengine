module extbmp.animation;

public struct AnimationData{
	string[] ID;
	int[] duration;

	public void addFrame(string ID, int lenght){
		this.ID ~= ID;
		this.duration ~= lenght;
	}


}

