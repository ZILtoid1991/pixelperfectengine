module pixelperfectengine.scripting.lua;

import bindbc.lua;

import core.vararg;

import std.string : toStringz, fromStringz;
import std.variant;
import std.typetuple;
import std.traits;
import std.exception : enforce;

import pixelperfectengine.system.exc;

import collections.linkedmap;

/** 
 * Initializes the Lua scripting engine.
 * Returns: true if successful.
 */
public bool initLua() {
	LuaSupport ver = loadLua();
	return ver == LuaSupport.lua54;
}
extern(C)
package void* luaAllocator(void* ud, void* ptr, size_t osize, size_t nsize) @system @nogc nothrow {
	import core.stdc.stdlib;
	if (nsize == 0) {
		free(ptr);
		return null;
	} else {
		return realloc(ptr, nsize);
	}
}
/** 
 * Calls a Lua function with the given name and arguments.
 * Params:
 *   state = The Lua state, where the function is located.
 *   ... = The arguments to be passed to the
 * Template params:
 *   T = The return type.
 *   funcName = The name of the function.
 * Returns: An expected return type, which can be set to a tagged algebraic type to avoid potential mismatches.
 * Throws: A LuaException if the return type isn't matched, the execution ran into an error, or the function isn't 
 * found.
 */
public T callLuaFunc(T, funcName)(lua_State* state, ...) @system {
	lua_getglobal(state, funcName);
	if (!lua_isfunction(state, LUA_TOP))
		throw new LuaException(8,"Function not found");
	static foreach (arg; _arguments) {
		static if (arg == typeid(byte)) {
			lua_pushinteger(state, va_arg!byte(_argptr));
		} else static if (arg == typeid(short)) {
			lua_pushinteger(state, va_arg!short(_argptr));
		} else static if (arg == typeid(int)) {
			lua_pushinteger(state, va_arg!int(_argptr));
		} else static if (arg == typeid(long)) {
			lua_pushinteger(state, va_arg!long(_argptr));
		} else static if (arg == typeid(ushort)) {
			lua_pushinteger(state, va_arg!ushort(_argptr));
		} else static if (arg == typeid(uint)) {
			lua_pushinteger(state, va_arg!uint(_argptr));
		} else static if (arg == typeid(ubyte)) {
			lua_pushinteger(state, va_arg!ubyte(_argptr));
		} else static if (arg == typeid(bool)) {
			lua_pushboolean(state, va_arg!bool(_argptr));
		} else static if (arg == typeid(double)) {
			lua_pushnumber(state, va_arg!double(_argptr));
		} else static if (arg == typeid(string)) {
			lua_pushstring(state, toStringz(va_arg!string(_argptr)));
		} else static if (arg == typeid(LuaVar)) {
			va_arg!LuaVar(_argptr).pushToLuaState(state);
		} else static assert(0, "Argument not supported!");
	}
	int errorCode = lua_pcall(state, cast(int)_arguments.length, is(T == void) ? 0 : 1, 0);
	return T.init;
}
/** 
 * Registers a D function to be called from Lua.
 * Code is modified from MrcSnm's example found in the HipremeEngine.
 * Params:
 *   state = The Lua state to handle the data from the Lua side of things.
 * Template params:
 *   Func = The function to be registered.
 */
extern(C) public int registerDFunction(alias Func)(lua_State* state) nothrow
		if(isSomeFunction!(Func)) {
	import std.traits:Parameters, ReturnType;
	
	Parameters!Func params;
	int stackCounter = 0;
	try {
		foreach_reverse(ref param; params) {
			stackCounter--;
			param = luaGetFromIndex!(typeof(param))(state, stackCounter);
		}
	} catch (Exception e) {
		luaL_error(state, "Argument type mismatch with D functions!");
	}
	
	try {
		static if(is(ReturnType!Func == void)) {
			Func(params);
			return 0;
		} else {
			LuaVar(Func(params)).pushToLuaState(state);
			return 1;
		}
	} catch (Exception e) {
		//luaPushVar(L, null);
		lastLuaToDException = e;
		try {
			luaL_error(state, ("A D function threw: "~e.toString~"!\0").ptr);
		} catch(Exception e) { 
			luaL_error(state, "D threw when stringifying exception!");
		}
		return 1;
	}
}
///Contains the pointer to the exception thrown by a D function called from the Lua side.
public static Exception lastLuaToDException;
package T luaGetFromIndex(T)(lua_State* L, int ind) {
	static if(isIntegral!T) {
		if (!lua_isinteger(L, ind)) 
			throw new LuaException(7,"Type mismatch!");
		lua_Integer i = lua_tointeger(L, ind);
		return cast(T)i;
	} else static if(isFloatingPoint!T) {
		if (!lua_isnumber(L, ind))
			throw new LuaException(7,"Type mismatch!");
		lua_Number n = lua_tonumber(L, ind);
		return cast(T)n;
	} else static if(is(T == string)) {
		import std.string : fromStringz;
		if (!lua_isstring(L, ind))
			throw new LuaException(7,"Type mismatch!");
		return fromStringz(lua_tostring(L, ind));
	} else static if(is(T == void*)) {
		if (!lua_islightuserdata(L, ind))
			throw new LuaException(7,"Type mismatch!");
		void* data = lua_touserdata(L, ind);
		return cast(T)data;
	} else static if(is(T == LuaVar)) {
		return LuaVar(L, ind);
	} else static assert(0, "Type not supported!");
	
}
public enum LuaVarType {
	Null,
	Boolean,
	Number,
	Integer,
	String,
	Function,
	Userdata,
	Thread,
	Table
}
/** 
 * Implements a Lua variable with all the underlying stuff required for it.
 */
public struct LuaVar {
	private LuaVarType		_type;
	private union {
		void*				dataPtr;
		long				dataInt;
		double				dataNum;
	}
	//private void*			data;
	public this(T)(T val) @safe pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			dataPtr = val;
		} else static if (isIntegral!T || isBoolean!T) {
			dataInt = val;
		} else static if (isFloatingPoint!T) {
			dataNum = val;
		} else static if (is(T == string)) {
			dataStr = val;
		}
		setType!(T);
	}
	public this(lua_State* state, int idx) nothrow {
		int type = lua_type(state, idx);
		switch (type) {
			case LUA_TLIGHTUSERDATA:
				dataPtr = lua_touserdata(state, idx);
				_type = LuaVarType.Userdata;
				break;
			case LUA_TBOOLEAN:
				dataInt = lua_toboolean(state, idx);
				_type = LuaVarType.Boolean;
				break;
			case LUA_TNUMBER:
				if (lua_isinteger(state, idx)) {
					dataInt = lua_tointeger(state, idx);
					_type = LuaVarType.Integer;
				} else {
					dataNum = lua_tonumber(state, idx);
					_type = LuaVarType.Number;
				}
				break;
			case LUA_TSTRING:
				dataPtr = cast(void*)lua_tostring(state, idx);
				_type = LuaVarType.String;
				break;
			default:
				break;
		}
	}
	private void setType(T)() @nogc @safe pure nothrow {
		static if (isIntegral!T) {
			_type = LuaVarType.Integer;
		} else static if (isBoolean!T) {
			_type = LuaVarType.Boolean;
		} else static if (isFloatingPoint!T) {
			_type = LuaVarType.Number;
		} else static if (is(T == string)) {
			_type = LuaVarType.String;
		} else static if (is(T == void*)) {
			_type = LuaVarType.Userdata;
		} else static if (is(T == LuaTable)) {
			_type = LuaVarType.Table;
		} else {
			_type = LuaVarType.Null;
		}
	}
	public LuaVarType type() const @nogc @safe pure nothrow {
		return _type;
	}
	private T deRef(T)() const @nogc @system pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			return cast(T)dataPtr;
		} else static if (isIntegral!T || isBoolean!T) {
			return cast(T)dataInt;
		} else static if (isFloatingPoint!T) {
			return cast(T)dataNum;
		} else static if (is(T == string)) {
			return fromStringz(cast(const(char*))dataPtr);
		}
	}
	package void pushToLuaState(lua_State* state) @system nothrow {
		final switch (_type) with (LuaVarType) {
			case Null:
				lua_pushnil(state);
				break;
			case Boolean:
				lua_pushboolean(state, deRef!bool());
				break;
			case Number:
				lua_pushnumber(state, deRef!double());
				break;
			case Integer:
				lua_pushinteger(state, deRef!long());
				break;
			case String:
				lua_pushstring(state, cast(const(char*))dataPtr);
				break;
			case Function:
				break;
			case Userdata:
				lua_pushlightuserdata(state, dataPtr);
				break;
			case Thread:
				break;
			case Table:
				break;
		}
	}
	public T get(T)() const @trusted pure {
		static if (is(typeof(T) == int) || is(typeof(T) == long)) {
			if (_type == LuaVarType.Integer)
				return cast(T)deRef!long;
		} else static if (is(typeof(T) == double) || is(typeof(T) == float)) {
			if (_type == LuaVarType.Integer)
				return cast(T)deRef!double;
		} else static if (is(typeof(T) == string)) {
			if (_type == LuaVarType.String)
				return deRef!string;
		} else static if (is(typeof(T) == void*)) {
			if (_type == LuaVarType.Userdata)
				return deRef!(void*);
		} else static if (is(typeof(T) == bool)) {
			if (_type == LuaVarType.Boolean)
				return deRef!bool;
		} else static if (is(typeof(T) == LuaTable*)) {
			if (_type == LuaVarType.Table)
				return deRef!(LuaTable*);
		} else static assert(0, "Type not supported!");
		throw new LuaException(7, "Wrong type!");
	}
	public bool opEquals(const LuaVar other) const @nogc @trusted pure nothrow {
		if (_type != other._type) return false;
		switch (_type) {
			case LuaVarType.Number:
				return deRef!double() == other.deRef!double();
			case LuaVarType.Integer:
				return deRef!long() == other.deRef!long();
			case LuaVarType.String:
				return deRef!string() == other.deRef!string();
			case LuaVarType.Boolean:
				return deRef!bool() == other.deRef!bool();
			case LuaVarType.Userdata:
				return deRef!(void*)() == other.deRef!(void*)();
			default:
				return false;
		}
	}
	public auto opAssign(T)(T val) @safe pure nothrow {
		static if (is(T == void*) || is(T == LuaTable*)) {
			dataPtr = val;
		} else static if (isIntegral!T || isBoolean!T) {
			dataInt = val;
		} else static if (isFloatingPoint!T) {
			dataNum = val;
		} else static if (is(T == string)) {
			dataStr = val;
		}
		setType!T;
		return this;
	}
	T opCast(T)() const @safe pure {
		return get!T();
	}
}

alias LuaTable = LinkedMap!(LuaVar, LuaVar);

public class LuaException : PPEException {
	public int errorCode;
	///
	@nogc @safe pure nothrow this(int errorCode, string msg, string file = __FILE__, size_t line = __LINE__, 
			Throwable nextInChain = null)
	{
		this.errorCode = errorCode;
		super(msg, file, line, nextInChain);
	}
	///
	@nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
	{
		super(msg, file, line, nextInChain);
	}
}