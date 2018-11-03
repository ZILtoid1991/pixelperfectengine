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
 * Mostly based upon the AVT tree algorithm with small modifications, with the intent to replace D's default associative arrays for GC-free operations,
 * and better speed (theoretical worst-case access times: aArray's = n, this' = log2(n)).
 * Tree traversal through D's Range capabilities.
 * TODO:
 * <ul>
 * <li>Implement tree traversal.</li>
 * <li>Improve tree optimization speeds.</li>
 * <li>Fix potential memory leakage issues.</li>
 * </ul>
 */
public struct BinarySearchTree(K, E){
	/**
	 * Implements a single tree node.
	 */
	public struct Node{
		K key;				///Indentifier key, also used for automatic sorting
		E elem;				///Stores the element referred by this node
		Node* left;			///lesser elements
		Node* right;		///greater elements

		@nogc this(K key, E elem, Node* left = null, Node* right = null){
			this.key = key;
			this.elem = elem;
			this.left = left;
			this.right = right;
		}

		@nogc int opApply(int delegate(Node) @nogc dg){
			if(left)
				if(left.opApply(dg))
					return 1;
			if(dg(this))
				return 1;
			if(right)
				if(right.opApply(dg))
					return 1;
			return 0;
		}
		@nogc int opCmp(ref Node rhs){
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
		 * Deallocates the memory allocated for the tree.
		 */
		@nogc void dealloc(){
			if(left){
				left.dealloc;
				free(left);
			}
			if(right){
				right.dealloc;
				free(right);
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
	private Node* root;		///Points to the root element
	private size_t nOfElements;			///Current number of elements
	/+private size_t curr, currHeight;
	private Node** traceF, traceR;	///Used for Range
	private Node* pos;+/

	/+/**
	 * Returns true if the range have reached one of the endpoints.
	 */
	public @nogc bool empty(){
		return nOfElements == curr;
	}
	/**
	 * Returns the front element.
	 */
	public @nogc Node front(){
		return *pos;
	}
	/**
	 * Jumps to the next front element and returns it.
	 */
	public @nogc Node popFront(){
		//if trace isn't allocated, then allocate it
		if(traceF is null){
			size_t height = root.height;
			traceF = cast(Node**)malloc(size_t.sizeof * height);
			while(--height){
				traceF[height] = null;
			}
			traceF[0] = root;
			//build up initial trace then return the smallest value
			bool found;
			while(!found){
				if(traceF[currHeight].left !is null){
					currHeight++;
				}else{
					pos = traceF[currHeight];
					found = true;
				}
			}
			return *pos;
		}
		//find the next smallest node
		bool found;
		K key = pos.key;
		while(!found){
			if(traceF[currHeight].key > pos.key){
				found = true
			}
		}
		curr++;
		return *pos;
	}+/
	/**
	 * Used for foreach iteration.
	 */
	public @nogc int opApply(int delegate(Node) @nogc dg){
		return root.opApply(dg);
	}
	/**
	 * Gets an element without allocation. Returns E.init if key not found.
	 */
	public @nogc E opIndex(K key){
		bool found;
		Node* crnt = root;
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
	 * Gets the pointer of an element.
	 */
	public @nogc E* getPtr(K key){
		bool found;
		Node* crnt = root;
		E* result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.key == key){
				found = true;
				result = &crnt.elem;
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
			root = cast(Node*)malloc(Node.sizeof);
			*root = Node(i,value);
			nOfElements++;
			return value;
		}
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
	protected @nogc void rebalanceTree(Node** node){
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
	protected @nogc bool insertAt(Node** node, K key, E val){
		if(key == (*node).key){
			(*node).elem = val;
			return false;
		}else if(key < (*node).key){
			if((*node).left is null){
				(*node).left = cast(Node*)malloc(Node.sizeof);
				*(*node).left = Node(key,val);
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
				(*node).right = cast(Node*)malloc(Node.sizeof);
				*(*node).right = Node(key,val);
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
		bool handside;
		Node* crnt = root;
		Node* prev;
		while(crnt !is null){
			if(crnt.key == key){
				if(crnt.left is null && crnt.right is null){
					free(crnt);
					if(prev !is null){
						if(handside)
							prev.right = null;
						else
							prev.left = null;
					}else{
						root = null;
					}
					crnt = null;
					nOfElements--;
				}else if(crnt.left is null){
					if(prev is null){
						root = crnt.right;
					}else{
						if(handside)
							prev.right = crnt.right;
						else
							prev.left = crnt.right;
					}
					free(crnt);
					crnt = null;
					nOfElements--;
				}else if(crnt.right is null){
					if(prev is null){
						root = crnt.left;
					}else{
						if(handside)
							prev.right = crnt.left;
						else
							prev.left = crnt.left;
					}
					free(crnt);
					crnt = null;
					nOfElements--;
				}else{
					Node* temp;
					if(handside){
						temp = findMin(prev.right);
					}else{
						temp = findMax(prev.right);
					}
					K tempKey = temp.key;
					E tempVal = temp.elem;
					Node* tempLHS = temp.left;
					Node* tempRHS = temp.right;
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
	 * Rotates the subtree to the left by one.
	 */
	protected @nogc void rotateLeft(Node** node){
		/*Node* temp = (*node).right;
		(*node).right = temp.left;
		temp.left = *node;
		*node = temp;
		(*node).bal = 0;
		temp.bal = 0;*/
		Node* temp = *node;	//save current node
		*node = temp.right;				//assign the first RHS to the root
		temp.right = (*node).left;		//assign the new root's LHS to the saved node's RHS
		(*node).left = temp;			//assign the saved node to the new root's LHS
		//(*node).bal = 0;				//reset new root's balance
		//temp.bal = 0;					//reset the new LHS's balance
	}
	/**
	 * Rotates the subtree to the right by one.
	 */
	protected @nogc void rotateRight(Node** node){
		/*Node* temp = (*node).left;
		(*node).left = temp.right;
		temp.right = *node;
		*node = temp;
		(*node).bal = 0;
		temp.bal = 0;*/
		Node* temp = *node;	//save current node
		*node = temp.left;				//assign the first LHS to the root
		temp.left = (*node).right;		//assign the new root's RHS to the saved node's LHS
		(*node).right = temp;			//assign the saved node to the new root's RHS
		//(*node).bal = 0;				//reset new root's balance
		//temp.bal = 0;					//reset the new RHS's balance
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateRightLeft(Node** node){
		Node* temp = (*node).right.left;	//save root.RHS.LHS
		(*node).right.left = temp.right;			//assign temp.RHS to root.RHS.LHS
		temp.right = (*node).right;					//assign root.RHS to temp.RHS
		(*node).right = temp;						//assign temp to root.RHS
		//temp.right.bal = 0;							//reset balance of temp.RHS
		rotateLeft(node);							//rotate the root to the left
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateLeftRight(Node** node){
		Node* temp = (*node).left.right;	//save root.LHS.RHS
		(*node).left.right = temp.left;				//assign temp.LHS to root.LHS.RHS
		temp.left = (*node).left;					//assign root.LHS to temp.LHS
		(*node).left = temp;						//assign temp to root.LHS
		//temp.left.bal = 0;							//reset balance of temp.LHS
		rotateRight(node);							//rotate the root to the right
	}
	/**
	 * Optimizes a BinarySearchTree by distributing nodes evenly.
	 */
	protected @nogc void optimize(Node** node){
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

	public Node*[] collectNodes(Node* source){
		Node*[] result;
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
	public @nogc Node* findMin(){
		bool found;
		Node* result = root;
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
	public @nogc Node* findMin(Node* from){
		bool found;
		Node* result = from;
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
	public @nogc Node* findMax(){
		bool found;
		Node* result = root;
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
	public @nogc Node* findMax(Node* from){
		bool found;
		Node* result = from;
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

/**
 * Implements a binary search tree without a key, meaning elements can be looked up in a different fashion, eg. through opEquals method overriding
 */
public struct BinarySearchTree2(Elem){
	/**
	 * Nodes for each branches.
	 */
	public struct Node{
		Elem elem;
		Node* left;
		Node* right;
		@nogc this(Elem elem, Node* left = null, Node* right = null){
			this.elem = elem;
			this.left = left;
			this.right = right;
		}
		@nogc int opCmp(T)(ref T rhs){
			return this.elem.opCmp(rhs.elem);
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
			string result = "[" ~ to!string(elem) ~ ";" ~ to!string(bal) ~ ";";
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
	private Node* root;

	private size_t nOfElements;			///Current number of elements


	/**
	 * Gets an element without allocation. Returns E.init if key not found.
	 */
	public @nogc Elem lookup(K)(K key){
		bool found;
		Node* crnt = root;
		Elem result;
		do{
			if(crnt is null){
				found = true;
			}else if(crnt.elem == key){
				found = true;
				result = crnt.elem;
			}else if(crnt.elem > key){
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
	public @nogc Elem add(Elem elem){
		if(root is null){
			root = cast(Node*)malloc(Node.sizeof);
			*root = Node(elem);
			nOfElements++;
			return elem;
		}
		if(insertAt(&root, elem)){
			rebalanceTree(&root);
			nOfElements++;
		}
		return elem;
	}
	/**
	 * Rebalances a tree.
	 */
	public @nogc void rebalanceTree(){
		rebalanceTree(&root);
	}
	protected @nogc void rebalanceTree(Node** node){
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
	protected @nogc bool insertAt(Node** node, Elem elem){
		if(elem == (*node).elem){
			(*node).elem = elem;
			return false;
		}else if(elem < (*node).elem){
			if((*node).left is null){
				(*node).left = cast(Node*)malloc(Node.sizeof);
				*(*node).left = Node(elem);
				if((*node).right is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).left), elem);
			}
		}else{
			if((*node).right is null){
				(*node).right = cast(Node*)malloc(Node.sizeof);
				*(*node).right = Node(elem);
				if((*node).left is null){
					return true;
				}else{
					return false;
				}
			}else{
				return insertAt(&((*node).right), elem);
			}
		}
	}
	/**
	 * Removes an element by key.
	 */
	public @nogc void remove(Elem elem){
		bool handside;
		Node* crnt = root;
		Node* prev;
		while(crnt !is null){
			if(crnt.elem == elem){
				if(crnt.left is null && crnt.right is null){
					free(crnt);
					if(prev !is null){
						if(handside)
							prev.right = null;
						else
							prev.left = null;
					}else{
						root = null;
					}
					crnt = null;
					nOfElements--;
				}else if(crnt.left is null){
					if(prev is null){
						root = crnt.right;
					}else{
						if(handside)
							prev.right = crnt.right;
						else
							prev.left = crnt.right;
					}
					free(crnt);
					crnt = null;
					nOfElements--;
				}else if(crnt.right is null){
					if(prev is null){
						root = crnt.left;
					}else{
						if(handside)
							prev.right = crnt.left;
						else
							prev.left = crnt.left;
					}
					free(crnt);
					crnt = null;
					nOfElements--;
				}else{
					Node* temp;
					if(handside){
						temp = findMin(prev.right);
					}else{
						temp = findMax(prev.right);
					}
					//K tempKey = temp.key;
					Elem tempVal = temp.elem;
					Node* tempLHS = temp.left;
					Node* tempRHS = temp.right;
					remove(tempVal);
					//crnt.key = tempKey;
					crnt.elem = tempVal;
					crnt.left = tempLHS;
					crnt.right = tempRHS;
					return;
				}
			}else if(crnt.elem > elem){
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
	 * Rotates the subtree to the left by one.
	 */
	protected @nogc void rotateLeft(Node** node){
		Node* temp = *node;	//save current node
		*node = temp.right;				//assign the first RHS to the root
		temp.right = (*node).left;		//assign the new root's LHS to the saved node's RHS
		(*node).left = temp;			//assign the saved node to the new root's LHS
	}
	/**
	 * Rotates the subtree to the right by one.
	 */
	protected @nogc void rotateRight(Node** node){
		Node* temp = *node;	//save current node
		*node = temp.left;				//assign the first LHS to the root
		temp.left = (*node).right;		//assign the new root's RHS to the saved node's LHS
		(*node).right = temp;			//assign the saved node to the new root's RHS
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateRightLeft(Node** node){
		Node* temp = (*node).right.left;	//save root.RHS.LHS
		(*node).right.left = temp.right;			//assign temp.RHS to root.RHS.LHS
		temp.right = (*node).right;					//assign root.RHS to temp.RHS
		(*node).right = temp;						//assign temp to root.RHS
		//temp.right.bal = 0;							//reset balance of temp.RHS
		rotateLeft(node);							//rotate the root to the left
	}
	/**
	 * Rotates the subtree to the right then to the left.
	 */
	protected @nogc void rotateLeftRight(Node** node){
		Node* temp = (*node).left.right;	//save root.LHS.RHS
		(*node).left.right = temp.left;				//assign temp.LHS to root.LHS.RHS
		temp.left = (*node).left;					//assign root.LHS to temp.LHS
		(*node).left = temp;						//assign temp to root.LHS
		//temp.left.bal = 0;							//reset balance of temp.LHS
		rotateRight(node);							//rotate the root to the right
	}
	/**
	 * Optimizes a BinarySearchTree by distributing nodes evenly.
	 */
	protected @nogc void optimize(Node** node){
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
	/**
	 * Finds the smallest value from the root.
	 */
	public @nogc Node* findMin(){
		bool found;
		Node* result = root;
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
	public @nogc Node* findMin(Node* from){
		bool found;
		Node* result = from;
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
	public @nogc Node* findMax(){
		bool found;
		Node* result = root;
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
	public @nogc Node* findMax(Node* from){
		bool found;
		Node* result = from;
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
		string result = " : Elem: " ~ Elem.stringof;
		if(root !is null)
			result ~= root.toString();
		return result;
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
