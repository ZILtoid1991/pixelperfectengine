module pixelperfectengine.system.platform;

version(X86){
	static enum ARCH_INTEL_X86 = true;
	version(LDC){
		static enum USE_INTEL_INTRINSICS = true;	///Enables the use of intel intrinsics in compilers that support it;
	}else{
		static enum USE_INTEL_INTRINSICS = false;
	}
}else version(X86_64){
	static enum ARCH_INTEL_X86 = true;
	version(LDC){
		static enum USE_INTEL_INTRINSICS = true;	///Enables the use of intel intrinsics in compilers that support it;
	}else{
		static enum USE_INTEL_INTRINSICS = false;
	}
}else{
	static enum ARCH_INTEL_X86 = false;
	static enum USE_INTEL_INTRINSICS = false;
}
