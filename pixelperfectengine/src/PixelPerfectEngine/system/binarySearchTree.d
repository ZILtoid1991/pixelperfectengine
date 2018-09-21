module PixelPerfectEngine.system.binarySearchTree;

/*
 * Copyright (C) 2015-2018, by Laszlo Szeremi under the Boost license.
 *
 * Pixel Perfect Engine, system.transformFunctions module
 */

import core.stdc.stdlib;
import core.stdc.string;

/**
 * Implements a mostly @nogc-able container format, with relatively fast access times.
 * Mostly based upon the AVT tree algorithm with small modifications, with the intent to replace D's default associative arrays for GC-free operations.
 * TODO: Implement ordered tree traversal.
 */
public struct BinarySearchTree(K, E){
	private BSTNode!(K, E)* root;		///Points to the root element
	private BSTNode!(K, E)* storage;	///Stores the pointer of the nodes
	//private sizediff_t bal;
	private size_t nOfElements;			///Current number of elements
	private size_t strCap;				///Storage capacity

	/*~this(){
		if(root !is null){
			BSTNode!(K, E)*[] nodes = collectNodes(root);
			foreach(n ; nodes){
				free(n);
			}
		}
	}*/
	/**
	 * Tree traversal for quick access.
	 * TODO: Make it NOGC
	 */
	/*public int opApply(scope int delegate(ref E) dg){
		int result;
		result = treeTraversalByDepth(dg, root);
		return result;
	}
	protected int treeTraversalByDepth(scope int delegate(ref E) dg, BSTNode!(K, E)* root){
		int result = dg(root.elem);
		if(result)
			return result;
		else{
			if(root.left !is null){
				result = treeTraversalByDepth(dg, root.left);
				if(result)
					return result;
			}
			if(root.right !is null){
				result = treeTraversalByDepth(dg, root.right);
				if(result)
					return result;
			}
		}
		return result;
	}*/
	/**
	 * Tree traversal, mostly follows the order in which the elements were added, removal might mix things up.
	 * Usage:
	 * int pos = -1, E elem, K key;
	 * while(bst.normalTreeTraversal(pos, elem, key)){
	 * [...]
	 * }
	 */
	public @nogc bool normalTreeTraversal(ref int pos, ref E elem, ref K key){
		pos++;
		if(pos >= nOfElements){
			return false;
		}
		elem = storage[pos].elem;
		key = storage[pos].key;
		return true;
	}
	/**
	 * Reserves a given amount of nodes. Does nothing if the new capacity is smaller than the number of elements.
	 * Returns the new capacity.
	 */
	public @nogc size_t reserve(size_t cap){
		if(nOfElements > cap)
			return strCap;
		storage = cast(BSTNode!(K,E)*)realloc(storage, cap * BSTNode!(K,E).sizeof);
		strCap = cap;
		return cap;
	}
	/**
	 * Grows the capacity by the power of two.
	 * Returns the new capacity.
	 */
	public @nogc size_t grow(){
		return reserve(strCap << 1);
	}
	/**
	 * Shrinks to the minimum size that is absolutely needed to store the elements of the tree.
	 * Returns the new capacity.
	 */
	public @nogc size_t shrink(){
		return reserve(nOfElements);
	}
	/**
	 * Gets an element without allocation. Returns E.init if key not found.
	 */
	public @nogc E opIndex(K key){
		bool found;
		BSTNode!(K, E)* crnt = root;
		E result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.key == key){
				found = true;
				result = crnt.elem;
			}else if(crnt.key > key){
				crnt = crnt.left;
			}else{
				crnt = crnt.right;
			}
		}while(!found);
		return result;
	}

	/**
	 * Inserts a new element with some automatic optimization.
	 * TODO: Make the optimization better.
	 */
	public @nogc E opIndexAssign(E value, K i){
		if(root is null){
			if(!strCap){
				reserve(1);
				root = storage;
			}
			*root = BSTNode!(K, E)(i,value);
			nOfElements++;
			return value;
		}
		if(strCap <= nOfElements)
			grow();
		if(insertAt(&root, i, value)){
			rebalanceTree(&root);
			nOfElements++;
		}
		return value;
	}
	/**
	 * Rebalances a tree.
	 */
	public @nogc void rebalanceTree(){
		rebalanceTree(&root);
	}
	protected @nogc void rebalanceTree(BSTNode!(K, E)** node){
		if((*node).height > 1){
			if((*node).bal > 1 || (*node).bal < -1){
				optimize(node);
			}
			if((*node).left !is null){
				rebalanceTree(&(*node).left);
			}
			if((*node).right !is null){
				rebalanceTree(&(*node).right);
			}
		}
	}
	/**
	 * Returns the number of elements in the tree.
	 */
	public @nogc @property size_t length(){
		return nOfElements;
	}
	/**
	 * Inserts an item at the given point. Returns true if the height of the tree have been raised.
	 */
	protected @nogc bool insertAt(BSTNode!(K, E)** node, K key, E val){
		if(key == (*node).key){
			(*node).elem = val;
			return false;
		}else if(key < (*node).key){
			if((*node).left is null){
				(*node).left = &storage[nOfElements];// = cast(BSTNode!(K, E)*)malloc(BSTNode!(K, E).sizeof);
				*(*node).left = BSTNode!(K, E)(key,val);
				if((*node).right is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).left), key, val);
			}
		}else{
			if((*node).right is null){
				(*node).right = cast(BSTNode!(K, E)*)malloc(BSTNode!(K, E).sizeof);
				*(*node).right = BSTNode!(K, E)(key,val);
				if((*node).left is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).right), key, val);
			}
		}
	}
	/**
	 * Removes an element by key.
	 */
	public @nogc void remove(K key){
		nOfElements--;
		bool handside;
		BSTNode!(K, E)* crnt = root;
		BSTNode!(K, E)* prev;
		while(crnt !is null){
			if(crnt.key == key){
				if(crnt.left is null && crnt.right is null){
					removeByPointer(crnt);
					if(prev !is null){
						if(handside)
							prev.right = null;
						else
							prev.left = null;
					}
					crnt = null;
				}else if(crnt.left is null){
					if(prev is null){
						root = crnt.right;
					}else{
						if(handside)
							prev.right = crnt.right;
						else
							prev.left = crnt.right;
					}
					removeByPointer(crnt);
					crnt = null;
				}else if(crnt.right is null){
					if(prev is null){
						root = crnt.left;
					}else{
						if(handside)
							prev.right = crnt.left;
						else
							prev.left = crnt.left;
					}
					removeByPointer(crnt);
					crnt = null;
				}else{
					BSTNode!(K, E)* temp;
					if(handside){
						temp = findMin(prev.right);
					}else{
						temp = findMax(prev.right);
					}
					K tempKey = temp.key;
					E tempVal = temp.elem;
					BSTNode!(K, E)* tempLHS = temp.left;
					BSTNode!(K, E)* tempRHS = temp.right;
					remove(tempKey);
					crnt.key = tempKey;
					crnt.elem = tempVal;
					crnt.left = tempLHS;
					crnt.right = tempRHS;
					return;
				}
			}else if(crnt.key > key){
				prev = crnt;
				handside = false;
				crnt = crnt.left;
			}else{
				prev = crnt;
				handside = true;
				crnt = crnt.right;
			}
		}
	}
	/**
	 * Deletes an item by pointer value, then updates the node references if needed.
	 */
	private @nogc void removeByPointer(BSTNode!(K, E)* node){
		const sizediff_t index = cast(sizediff_t)(node - storage);
		if (index != nOfElements){
			for (int i = index ; index < nOfElements ; i++){
				for (int j ; j < nOfElements ; j++){
					if (storage[j].left == storage + i){
						storage[j].left--;
					}
					if (storage[j].right == storage + i){
						storage[j].right--;
					}
				}
			}
			memcpy(cast(void*)(storage + index), cast(void*)(storage + index + 1), nOfElements - index);
		}
	}
	/**
	 * Rotates the subtree to the left by one.
	 */
	protected @nogc void rotateLeft(BSTNode!(K, E)** node){
		/*BSTNode!(K, E)* temp = (*node).right;
		(*node).right = temp.left;
		temp.left = *node;
		*node = temp;
		(*node).bal = 0;
		temp.bal = 0;*/
		BSTNode!(K, E)* temp = *node;	//save current node
		*node = temp.right;				//assign the first RHS to the root
		temp.right = (*node).left;		//assign the new root's LHS to the saved node's RHS
		(*node).left = temp;			//assign the saved node to the new root's LHS
		//(*node).bal = 0;				//reset new root's balance
		//temp.bal = 0;					//reset the new LHS's balance
	}
	/**
	 * Rotates the subtree to the right by one.
	 */
	protected @nogc void rotateRight(BSTNode!(K, E)** node){
		/*BSTNode!(K, E)* temp = (*node).left;
		(*node).left = temp.right;
		temp.right = *node;
		*node = temp;
		(*node).bal = 0;
		temp.bal = 0;*/
		BSTNode!(K, E)* temp = *node;	//save current node
		*node = temp.left;				//assign the first LHS to the root
		temp.left = (*node).right;		//assign the new root's RHS to the saved node's LHS
		(*node).right = temp;			//assign the saved node to the new root's RHS
		//(*node).bal = 0;				//reset new root's balance
		//temp.bal = 0;					//reset the new RHS's balance
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateRightLeft(BSTNode!(K, E)** node){
		BSTNode!(K, E)* temp = (*node).right.left;	//save root.RHS.LHS
		(*node).right.left = temp.right;			//assign temp.RHS to root.RHS.LHS
		temp.right = (*node).right;					//assign root.RHS to temp.RHS
		(*node).right = temp;						//assign temp to root.RHS
		//temp.right.bal = 0;							//reset balance of temp.RHS
		rotateLeft(node);							//rotate the root to the left
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateLeftRight(BSTNode!(K, E)** node){
		BSTNode!(K, E)* temp = (*node).left.right;	//save root.LHS.RHS
		(*node).left.right = temp.left;				//assign temp.LHS to root.LHS.RHS
		temp.left = (*node).left;					//assign root.LHS to temp.LHS
		(*node).left = temp;						//assign temp to root.LHS
		//temp.left.bal = 0;							//reset balance of temp.LHS
		rotateRight(node);							//rotate the root to the right
	}
	/**
	 * Optimizes a BinarySearchTree by distributing nodes evenly.
	 */
	protected @nogc void optimize(BSTNode!(K, E)** node){
		if((*node).bal >= 2){
			if((*node).right.bal >= 1){
				rotateLeft(node);
			}else if((*node).right.bal <= -1){
				rotateRightLeft(node);
			}
		}else if((*node).bal <= -2){
			if((*node).left.bal >= 1){
				rotateLeftRight(node);
			}else if((*node).left.bal <= -1){
				rotateRight(node);
			}
		}

	}

	public BSTNode!(K, E)*[] collectNodes(BSTNode!(K, E)* source){
		BSTNode!(K, E)*[] result;
		if(source !is null){
			result ~= source;
			if(source.left !is null)
				result ~= collectNodes(source.left);
			if(source.right !is null)
				result ~= collectNodes(source.right);
		}
		return result;
	}
	/**
	 * Finds the smallest value from the root.
	 */
	public @nogc BSTNode!(K, E)* findMin(){
		bool found;
		BSTNode!(K, E)* result = root;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the smallest value from the given root.
	 */
	public @nogc BSTNode!(K, E)* findMin(BSTNode!(K, E)* from){
		bool found;
		BSTNode!(K, E)* result = from;
		do{
			if(result.left is null)
				found = true;
			else
				result = result.left;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the root.
	 */
	public @nogc BSTNode!(K, E)* findMax(){
		bool found;
		BSTNode!(K, E)* result = root;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}
	/**
	 * Finds the largest value from the given root.
	 */
	public @nogc BSTNode!(K, E)* findMax(BSTNode!(K, E)* from){
		bool found;
		BSTNode!(K, E)* result = from;
		do{
			if(result.right is null)
				found = true;
			else
				result = result.right;
		}while(!found);
		return result;
	}

	public string toString(){
		import std.conv;
		string result = "Key: " ~ K.stringof ~ " : Elem: " ~ E.stringof;
		if(root !is null)
			result ~= root.toString();
		return result;
	}
}

public struct BSTNode(K, E){
	K key;
	E elem;
	BSTNode!(K, E)* left;		//lesser elements
	BSTNode!(K, E)* right;		//greater elements

	@nogc this(K key, E elem, BSTNode!(K, E)* left = null, BSTNode!(K, E)* right = null){
		this.key = key;
		this.elem = elem;
		this.left = left;
		this.right = right;
	}

	@nogc int opCmp(ref BSTNode!(K, E) rhs){
		return key - rhs.key;
	}
	/**
	 * Returns the total height.
	 */
	@nogc @property size_t height(){
		if(left is null && right is null){
			return 1;
		}else{
			size_t l = 1, r = 1;
			if(left !is null){
				l += left.height;
			}
			if(right !is null){
				r += right.height;
			}
			if(l >= r){
				return l;
			}else{
				return r;
			}
		}
	}
	/**
	 * Returns the balance of the node. Minus if LHS is heavier, plus if RHS is heavier.
	 */
	@nogc @property sizediff_t bal(){
		if(left is null && right is null){
			return 0;
		}else{
			size_t l, r;
			if(left !is null){
				l = left.height;
			}
			if(right !is null){
				r = right.height;
			}
			return r - l;
		}
	}
	/**
	 * String representation for debugging.
	 */
	public string toString(){
		import std.conv;
		string result = "[" ~ to!string(key) ~ ":" ~ to!string(elem) ~ ";" ~ to!string(bal) ~ ";";
		if(left is null){
			result ~= "lhs: null ";
		}else{
			result ~= " lhs: " ~ left.toString;
		}
		if(right is null){
			result ~= "rhs: null ";
		}else{
			result ~= " rhs: " ~ right.toString;
		}
		return result ~ "]";
	}
}
unittest{
	import std.stdio;
	import std.random;

	BinarySearchTree!(int,int) test0, test1;
	//test 0: fill tree with consequential values
	for(int i ; i < 32 ; i++){
		test0[i] = i;
	}
	writeln(test0);
	//test 1: fill tree with random values
	for(int i ; i < 32 ; i++){
		test0[rand()] = i;
	}
	writeln(test1);
}
