# DSA (Data Structures & Algorithms) Interview Questions

## Arrays & Strings

**Q1: What is the time complexity of accessing an element in an array vs a linked list?**

Array access is O(1) because elements are stored in contiguous memory and can be indexed directly. Linked list access is O(n) because you must traverse from the head node to reach the desired position.

**Q2: How would you find the two numbers in an array that sum to a target value?**

The brute-force approach is O(n²) — check every pair. The optimal approach uses a hash map: iterate through the array, and for each element check if `target - element` exists in the map. If yes, you've found the pair. If no, add the element to the map. This runs in O(n) time and O(n) space.

```csharp
public int[] TwoSum(int[] nums, int target) {
    var map = new Dictionary<int, int>();
    for (int i = 0; i < nums.Length; i++) {
        int complement = target - nums[i];
        if (map.ContainsKey(complement))
            return new[] { map[complement], i };
        map[nums[i]] = i;
    }
    return Array.Empty<int>();
}
```

**Q3: How do you find the maximum subarray sum (Kadane's Algorithm)?**

Maintain a running sum and a global maximum. At each element, decide whether to extend the current subarray or start fresh from that element. Time: O(n), Space: O(1).

```csharp
public int MaxSubArray(int[] nums) {
    int maxSum = nums[0], currentSum = nums[0];
    for (int i = 1; i < nums.Length; i++) {
        currentSum = Math.Max(nums[i], currentSum + nums[i]);
        maxSum = Math.Max(maxSum, currentSum);
    }
    return maxSum;
}
```

**Q4: How would you rotate an array to the right by k positions?**

Reverse the entire array, then reverse the first k elements, then reverse the remaining n-k elements. Time: O(n), Space: O(1).

**Q5: How do you check if a string is a palindrome?**

Use two pointers — one at the start and one at the end — moving inward. Compare characters at each step. Time: O(n), Space: O(1).

---

## Linked Lists

**Q6: How do you detect a cycle in a linked list?**

Floyd's Cycle Detection (Tortoise and Hare): use two pointers — slow moves one step at a time, fast moves two steps. If they ever meet, a cycle exists. Time: O(n), Space: O(1).

```csharp
public bool HasCycle(ListNode head) {
    var slow = head;
    var fast = head;
    while (fast != null && fast.next != null) {
        slow = slow.next;
        fast = fast.next.next;
        if (slow == fast) return true;
    }
    return false;
}
```

**Q7: How do you reverse a linked list?**

Iteratively: maintain a `prev` pointer (initially null), a `current` pointer (head), and a `next` pointer. At each step, save `current.next`, point `current.next` to `prev`, advance `prev` to `current`, and advance `current` to the saved `next`. Time: O(n), Space: O(1).

**Q8: How do you find the middle of a linked list?**

Use two pointers — slow and fast. When fast reaches the end, slow is at the middle. Time: O(n), Space: O(1).

**Q9: How do you merge two sorted linked lists?**

Use a dummy head node. Compare the heads of both lists, attach the smaller one to the result, and advance that list's pointer. Continue until one list is exhausted, then attach the remainder. Time: O(m+n), Space: O(1).

---

## Stacks & Queues

**Q10: How do you implement a stack using two queues?**

Push: enqueue to queue1. Pop: move all elements from queue1 to queue2 except the last one, dequeue and return the last element from queue1, then swap queue names.

**Q11: How do you validate balanced parentheses?**

Use a stack. For opening brackets, push. For closing brackets, check if the stack is non-empty and the top matches — if not, return false. At the end, the stack should be empty.

```csharp
public bool IsValid(string s) {
    var stack = new Stack<char>();
    foreach (char c in s) {
        if (c == '(' || c == '{' || c == '[') stack.Push(c);
        else {
            if (stack.Count == 0) return false;
            char top = stack.Pop();
            if (c == ')' && top != '(') return false;
            if (c == '}' && top != '{') return false;
            if (c == ']' && top != '[') return false;
        }
    }
    return stack.Count == 0;
}
```

**Q12: What is a monotonic stack and when do you use it?**

A monotonic stack maintains elements in sorted order (increasing or decreasing). It's used for problems like "next greater element", "largest rectangle in histogram", and "daily temperatures". When a new element violates the monotonic property, elements are popped and processed.

---

## Trees & Binary Search Trees

**Q13: What are the three depth-first traversal orders for a binary tree?**

- **In-order** (Left → Root → Right): produces sorted output for a BST.
- **Pre-order** (Root → Left → Right): useful for copying/serializing a tree.
- **Post-order** (Left → Right → Root): useful for deletion or computing sizes.

**Q14: How do you find the lowest common ancestor (LCA) of two nodes in a BST?**

Start at root. If both values are less than root, go left. If both are greater, go right. Otherwise, the current node is the LCA. Time: O(h) where h is height.

**Q15: How do you check if a binary tree is balanced?**

A tree is balanced if the height difference between left and right subtrees is at most 1 for every node. Use a recursive helper that returns -1 if unbalanced, or the height otherwise. Time: O(n).

**Q16: How do you do a level-order (BFS) traversal?**

Use a queue. Enqueue the root, then process level by level: for each node dequeued, add its value to the result and enqueue its non-null children.

```csharp
public IList<IList<int>> LevelOrder(TreeNode root) {
    var result = new List<IList<int>>();
    if (root == null) return result;
    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    while (queue.Count > 0) {
        int levelSize = queue.Count;
        var level = new List<int>();
        for (int i = 0; i < levelSize; i++) {
            var node = queue.Dequeue();
            level.Add(node.val);
            if (node.left != null) queue.Enqueue(node.left);
            if (node.right != null) queue.Enqueue(node.right);
        }
        result.Add(level);
    }
    return result;
}
```

**Q17: What is the time complexity of BST operations?**

Average case: O(log n) for search, insert, delete. Worst case (skewed tree): O(n). Balanced BSTs (AVL, Red-Black) guarantee O(log n) worst case.

---

## Graphs

**Q18: What is the difference between BFS and DFS?**

BFS uses a queue and explores neighbors level by level — good for shortest path in unweighted graphs. DFS uses a stack (or recursion) and explores as deep as possible before backtracking — good for cycle detection, topological sort, and connected components.

**Q19: How do you detect a cycle in a directed graph?**

Use DFS with three states per node: unvisited, in-progress, visited. If during DFS you encounter an in-progress node, a cycle exists. This is the basis of topological sort validation.

**Q20: What is topological sort and when is it used?**

Topological sort orders nodes in a directed acyclic graph (DAG) such that for every edge u→v, u comes before v. It's used in task scheduling, build systems (make/webpack), and course prerequisite resolution. Implemented via DFS post-order or Kahn's algorithm (BFS with in-degree tracking).

**Q21: Explain Dijkstra's algorithm.**

Dijkstra finds the shortest path from a source node to all other nodes in a weighted graph with non-negative edges. It uses a min-heap (priority queue): start with distance 0 at source and infinity for all others. Repeatedly extract the node with minimum distance, then relax its neighbors. Time: O((V + E) log V).

**Q22: What is Union-Find (Disjoint Set Union) and when is it used?**

Union-Find is a data structure that tracks connected components. It supports two operations: `find` (which component does a node belong to) and `union` (merge two components). With path compression and union by rank, both operations are nearly O(1). Used in Kruskal's MST algorithm and cycle detection in undirected graphs.

---

## Sorting & Searching

**Q23: Compare the major sorting algorithms.**

| Algorithm | Best | Average | Worst | Space | Stable |
|-----------|------|---------|-------|-------|--------|
| Bubble Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Selection Sort | O(n²) | O(n²) | O(n²) | O(1) | No |
| Insertion Sort | O(n) | O(n²) | O(n²) | O(1) | Yes |
| Merge Sort | O(n log n) | O(n log n) | O(n log n) | O(n) | Yes |
| Quick Sort | O(n log n) | O(n log n) | O(n²) | O(log n) | No |
| Heap Sort | O(n log n) | O(n log n) | O(n log n) | O(1) | No |

**Q24: How does binary search work and what are its requirements?**

Binary search requires a sorted array. It compares the target to the middle element: if equal, done; if less, search the left half; if greater, search the right half. Time: O(log n), Space: O(1). Edge cases: always check for integer overflow when computing mid — use `left + (right - left) / 2` instead of `(left + right) / 2`.

**Q25: What is the difference between Quick Sort and Merge Sort?**

Quick Sort is in-place (O(log n) space) but has O(n²) worst case with bad pivots; it's generally faster in practice due to cache locality. Merge Sort is stable and guarantees O(n log n) but requires O(n) extra space. For external sorting (large datasets on disk), Merge Sort is preferred.

---

## Dynamic Programming

**Q26: What is dynamic programming and how do you identify a DP problem?**

DP solves problems by breaking them into overlapping subproblems and storing results to avoid recomputation (memoization or tabulation). Signs it's a DP problem: the problem asks for a count, maximum, minimum, or yes/no, and can be broken into smaller subproblems that overlap. Classic examples: Fibonacci, knapsack, longest common subsequence.

**Q27: What is the difference between memoization (top-down) and tabulation (bottom-up)?**

Memoization is recursive with a cache — you solve subproblems only when needed. Tabulation is iterative — you fill a table from base cases up. Tabulation is typically more space-efficient and avoids recursion stack overflow; memoization is more intuitive to reason about.

**Q28: How do you solve the 0/1 Knapsack problem?**

Use a 2D DP table `dp[i][w]` = max value using first `i` items with capacity `w`. For each item, either skip it (`dp[i-1][w]`) or take it if it fits (`dp[i-1][w-weight[i]] + value[i]`). Time: O(n×W), Space: O(n×W), optimizable to O(W) with a 1D array.

**Q29: How do you find the longest common subsequence (LCS)?**

Use a 2D DP table. If characters match, `dp[i][j] = dp[i-1][j-1] + 1`. Otherwise `dp[i][j] = max(dp[i-1][j], dp[i][j-1])`. Time: O(m×n), Space: O(m×n).

**Q30: Explain the coin change problem.**

Given coin denominations and an amount, find the minimum number of coins to make the amount. Use bottom-up DP: `dp[i] = min(dp[i], dp[i - coin] + 1)` for each coin. Initialize `dp[0] = 0` and all others to infinity. Time: O(amount × coins).

---

## Hashing

**Q31: How does a hash map work internally?**

A hash map uses a hash function to map keys to bucket indices. Collisions (two keys mapping to the same bucket) are handled via chaining (linked list at each bucket) or open addressing (probing for the next empty slot). .NET's `Dictionary<K,V>` uses open addressing with quadratic probing. Average O(1) for get/set; O(n) worst case with many collisions.

**Q32: How do you find the first non-repeating character in a string?**

Use a `Dictionary<char, int>` to count occurrences in one pass, then iterate the string again and return the first character with count 1. Time: O(n), Space: O(1) (bounded by alphabet size).

---

## Two Pointers & Sliding Window

**Q33: What is the sliding window technique?**

Sliding window maintains a window of elements defined by two pointers (left and right) that expand and contract based on a condition. Used for problems like "longest substring without repeating characters", "maximum sum subarray of size k", and "minimum window substring". Avoids nested loops, reducing O(n²) to O(n).

**Q34: How do you find the longest substring without repeating characters?**

Use a sliding window with a hash set. Expand the right pointer. If the character is already in the set, shrink from the left until it's removed. Track the maximum window size. Time: O(n).

```csharp
public int LengthOfLongestSubstring(string s) {
    var set = new HashSet<char>();
    int left = 0, maxLen = 0;
    for (int right = 0; right < s.Length; right++) {
        while (set.Contains(s[right]))
            set.Remove(s[left++]);
        set.Add(s[right]);
        maxLen = Math.Max(maxLen, right - left + 1);
    }
    return maxLen;
}
```

---

## Recursion & Backtracking

**Q35: What is backtracking and when do you use it?**

Backtracking is a form of recursion where you explore a solution space, undo a choice if it leads to a dead end, and try the next option. Used for combinatorial problems: permutations, subsets, N-Queens, Sudoku solver, word search. Time complexity is often exponential.

**Q36: How do you generate all subsets of an array?**

Use backtracking: at each index, decide to include or exclude the element and recurse. Alternatively, use bit manipulation — for n elements there are 2^n subsets, each represented by a bitmask.

---

## Complexity Analysis

**Q37: What is Big O notation and what does it measure?**

Big O describes the upper bound of an algorithm's time or space growth as input size n approaches infinity. It ignores constants and lower-order terms. O(1) is constant, O(log n) is logarithmic, O(n) is linear, O(n log n) is linearithmic, O(n²) is quadratic, O(2^n) is exponential.

**Q38: What is the difference between time complexity and space complexity?**

Time complexity measures the number of operations as a function of input size. Space complexity measures the extra memory used. Sometimes there's a trade-off: hash maps reduce time at the cost of space; in-place algorithms save space but may be slower.

**Q39: What does amortized O(1) mean?**

Amortized analysis averages the cost over a sequence of operations. A dynamic array (like `List<T>`) has amortized O(1) append — most appends are O(1), but occasional resizing is O(n). Spread over n appends, the average is still O(1).

---

## Common Patterns Summary

| Pattern | When to Use |
|---------|-------------|
| Two Pointers | Sorted arrays, palindrome checks, pair sums |
| Sliding Window | Subarray/substring with constraints |
| Fast & Slow Pointers | Cycle detection, finding midpoint |
| BFS | Shortest path, level-order traversal |
| DFS + Backtracking | Permutations, combinations, graph traversal |
| Dynamic Programming | Overlapping subproblems, optimal substructure |
| Binary Search | Sorted data, search space reduction |
| Monotonic Stack | Next greater/smaller element problems |
| Union-Find | Connected components, cycle detection |
| Trie | Prefix search, autocomplete |
