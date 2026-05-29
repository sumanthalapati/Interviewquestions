# 🧩 DSA Interview Questions — Complete Guide

> **60+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Arrays & Strings](#1-arrays--strings)
2. [Linked Lists](#2-linked-lists)
3. [Stacks & Queues](#3-stacks--queues)
4. [Trees & Binary Search Trees](#4-trees--binary-search-trees)
5. [Graphs](#5-graphs)
6. [Sorting & Searching](#6-sorting--searching)
7. [Dynamic Programming](#7-dynamic-programming)
8. [Two Pointers & Sliding Window](#8-two-pointers--sliding-window)
9. [Recursion & Backtracking](#9-recursion--backtracking)
10. [Complexity Analysis](#10-complexity-analysis)

---

# 1. Arrays & Strings

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/arrays/
> 📚 LeetCode Patterns: https://leetcode.com/explore/learn/card/array-and-string/

---

## 1.1 Two Sum / Hash Map Lookup

### Q1. How do you find two numbers in an array that sum to a target value?

**Answer:**
The brute-force approach checks every pair in O(n²). The optimal approach uses a hash map: iterate through the array, and for each element check if `target - element` exists in the map. If yes, return the pair. If no, store the element. This runs in O(n) time and O(n) space.

❌ **Wrong — O(n²) nested loop, doesn't scale:**
```csharp
public int[] TwoSum(int[] nums, int target) {
    for (int i = 0; i < nums.Length; i++)
        for (int j = i + 1; j < nums.Length; j++)
            if (nums[i] + nums[j] == target)
                return new[] { i, j };
    return Array.Empty<int>();
}
```

✅ **Correct — O(n) with hash map:**
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

---

## 1.2 Maximum Subarray (Kadane's Algorithm)

### Q2. How do you find the contiguous subarray with the largest sum?

**Answer:**
Kadane's algorithm maintains a running sum. At each element, decide whether to extend the current subarray or start fresh from that element. Track the global maximum. Time: O(n), Space: O(1).

❌ **Wrong — recomputes every subarray, O(n²) time:**
```csharp
public int MaxSubArray(int[] nums) {
    int max = int.MinValue;
    for (int i = 0; i < nums.Length; i++) {
        int sum = 0;
        for (int j = i; j < nums.Length; j++) {
            sum += nums[j];
            max = Math.Max(max, sum);
        }
    }
    return max;
}
```

✅ **Correct — Kadane's, O(n) time:**
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

---

## 1.3 Palindrome Check

### Q3. How do you check if a string is a palindrome efficiently?

**Answer:**
Use two pointers — one from the start, one from the end — moving inward and comparing characters. Time: O(n), Space: O(1). Avoid reversing the string unnecessarily, which creates an O(n) space copy.

❌ **Wrong — creates a reversed copy, wastes O(n) space:**
```csharp
public bool IsPalindrome(string s) {
    string reversed = new string(s.Reverse().ToArray());
    return s == reversed;
}
```

✅ **Correct — two pointer, O(1) space:**
```csharp
public bool IsPalindrome(string s) {
    int left = 0, right = s.Length - 1;
    while (left < right) {
        if (s[left] != s[right]) return false;
        left++;
        right--;
    }
    return true;
}
```

---

## 1.4 Array Rotation

### Q4. How do you rotate an array to the right by k positions in-place?

**Answer:**
The triple-reverse trick: reverse the whole array, reverse the first k elements, then reverse the rest. No extra array needed. Time: O(n), Space: O(1).

❌ **Wrong — uses O(n) extra space:**
```csharp
public void Rotate(int[] nums, int k) {
    int n = nums.Length;
    k %= n;
    int[] temp = new int[n];
    for (int i = 0; i < n; i++)
        temp[(i + k) % n] = nums[i];
    Array.Copy(temp, nums, n);
}
```

✅ **Correct — in-place triple reverse:**
```csharp
public void Rotate(int[] nums, int k) {
    k %= nums.Length;
    Reverse(nums, 0, nums.Length - 1);
    Reverse(nums, 0, k - 1);
    Reverse(nums, k, nums.Length - 1);
}

private void Reverse(int[] nums, int left, int right) {
    while (left < right) {
        (nums[left], nums[right]) = (nums[right], nums[left]);
        left++; right--;
    }
}
```

---

# 2. Linked Lists

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.linkedlist-1
> 📚 Visual guide: https://visualgo.net/en/list

---

## 2.1 Cycle Detection

### Q5. How do you detect a cycle in a linked list?

**Answer:**
Floyd's Cycle Detection (Tortoise and Hare): two pointers — slow moves one step, fast moves two steps. If they meet, a cycle exists. Time: O(n), Space: O(1).

❌ **Wrong — uses a HashSet, O(n) space:**
```csharp
public bool HasCycle(ListNode head) {
    var visited = new HashSet<ListNode>();
    while (head != null) {
        if (!visited.Add(head)) return true;
        head = head.next;
    }
    return false;
}
```

✅ **Correct — Floyd's two-pointer, O(1) space:**
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

---

## 2.2 Reverse a Linked List

### Q6. How do you reverse a singly linked list in-place?

**Answer:**
Iteratively maintain three pointers: `prev` (null), `current` (head), `next`. At each step save `current.next`, redirect `current.next` to `prev`, advance both. Time: O(n), Space: O(1).

❌ **Wrong — recursive approach uses O(n) call stack space:**
```csharp
public ListNode Reverse(ListNode head) {
    if (head == null || head.next == null) return head;
    var newHead = Reverse(head.next);
    head.next.next = head;
    head.next = null;
    return newHead;
}
```

✅ **Correct — iterative, O(1) space:**
```csharp
public ListNode ReverseList(ListNode head) {
    ListNode prev = null, current = head;
    while (current != null) {
        var next = current.next;
        current.next = prev;
        prev = current;
        current = next;
    }
    return prev;
}
```

---

## 2.3 Merge Two Sorted Lists

### Q7. How do you merge two sorted linked lists?

**Answer:**
Use a dummy head node to simplify edge cases. Compare the two heads, attach the smaller, advance that list's pointer. Attach any remaining list at the end. Time: O(m+n), Space: O(1).

❌ **Wrong — creates a new list with extra allocation:**
```csharp
public ListNode MergeTwoLists(ListNode l1, ListNode l2) {
    var result = new List<int>();
    while (l1 != null) { result.Add(l1.val); l1 = l1.next; }
    while (l2 != null) { result.Add(l2.val); l2 = l2.next; }
    result.Sort();
    // rebuild list from sorted array — extra O(m+n) space
    ...
}
```

✅ **Correct — in-place weave with dummy head:**
```csharp
public ListNode MergeTwoLists(ListNode l1, ListNode l2) {
    var dummy = new ListNode(0);
    var current = dummy;
    while (l1 != null && l2 != null) {
        if (l1.val <= l2.val) { current.next = l1; l1 = l1.next; }
        else { current.next = l2; l2 = l2.next; }
        current = current.next;
    }
    current.next = l1 ?? l2;
    return dummy.next;
}
```

---

# 3. Stacks & Queues

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.stack-1
> 📚 NeetCode: https://neetcode.io/roadmap (Stack section)

---

## 3.1 Valid Parentheses

### Q8. How do you check if a string of brackets is balanced?

**Answer:**
Use a stack. Push opening brackets. For closing brackets, check if the stack top matches. At the end, the stack must be empty. Time: O(n), Space: O(n).

❌ **Wrong — counter-based, fails on interleaved types like `"([)]"`:**
```csharp
public bool IsValid(string s) {
    int count = 0;
    foreach (char c in s) {
        if (c == '(' || c == '{' || c == '[') count++;
        else count--;
        if (count < 0) return false;
    }
    return count == 0;
}
```

✅ **Correct — stack-based, handles all bracket types:**
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

---

## 3.2 Monotonic Stack — Next Greater Element

### Q9. How do you find the next greater element for each position in an array?

**Answer:**
A monotonic decreasing stack stores indices of unresolved elements. When a greater element is found, pop and record the answer for popped indices. Time: O(n), Space: O(n).

❌ **Wrong — O(n²) nested loop:**
```csharp
public int[] NextGreaterElement(int[] nums) {
    int n = nums.Length;
    int[] result = new int[n];
    for (int i = 0; i < n; i++) {
        result[i] = -1;
        for (int j = i + 1; j < n; j++) {
            if (nums[j] > nums[i]) { result[i] = nums[j]; break; }
        }
    }
    return result;
}
```

✅ **Correct — monotonic stack, O(n):**
```csharp
public int[] NextGreaterElement(int[] nums) {
    int n = nums.Length;
    int[] result = Enumerable.Repeat(-1, n).ToArray();
    var stack = new Stack<int>(); // stores indices
    for (int i = 0; i < n; i++) {
        while (stack.Count > 0 && nums[i] > nums[stack.Peek()])
            result[stack.Pop()] = nums[i];
        stack.Push(i);
    }
    return result;
}
```

---

# 4. Trees & Binary Search Trees

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/api/system.collections.generic.sorteddictionary-2
> 📚 Visualizer: https://visualgo.net/en/bst

---

## 4.1 Level-Order (BFS) Traversal

### Q10. How do you traverse a binary tree level by level?

**Answer:**
Use a queue. Enqueue the root, then for each level, process exactly `queue.Count` nodes, enqueue their children. Time: O(n), Space: O(n).

❌ **Wrong — DFS pre-order, not level-order:**
```csharp
public IList<IList<int>> LevelOrder(TreeNode root) {
    var result = new List<IList<int>>();
    void Dfs(TreeNode node) {
        if (node == null) return;
        result.Add(new List<int> { node.val }); // wrong structure
        Dfs(node.left);
        Dfs(node.right);
    }
    Dfs(root);
    return result;
}
```

✅ **Correct — BFS with queue:**
```csharp
public IList<IList<int>> LevelOrder(TreeNode root) {
    var result = new List<IList<int>>();
    if (root == null) return result;
    var queue = new Queue<TreeNode>();
    queue.Enqueue(root);
    while (queue.Count > 0) {
        int size = queue.Count;
        var level = new List<int>();
        for (int i = 0; i < size; i++) {
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

---

## 4.2 Validate Binary Search Tree

### Q11. How do you verify that a binary tree is a valid BST?

**Answer:**
Pass min/max bounds through recursion. Each node must be strictly within the bounds inherited from its ancestors. Time: O(n), Space: O(h).

❌ **Wrong — only checks immediate children, misses deeper violations:**
```csharp
public bool IsValidBST(TreeNode root) {
    if (root == null) return true;
    if (root.left != null && root.left.val >= root.val) return false;
    if (root.right != null && root.right.val <= root.val) return false;
    return IsValidBST(root.left) && IsValidBST(root.right);
    // fails for: root=5, left subtree has a node with val=6 (should be < 5)
}
```

✅ **Correct — propagates min/max bounds:**
```csharp
public bool IsValidBST(TreeNode root) => Validate(root, long.MinValue, long.MaxValue);

private bool Validate(TreeNode node, long min, long max) {
    if (node == null) return true;
    if (node.val <= min || node.val >= max) return false;
    return Validate(node.left, min, node.val) &&
           Validate(node.right, node.val, max);
}
```

---

## 4.3 Lowest Common Ancestor

### Q12. How do you find the LCA of two nodes in a BST?

**Answer:**
In a BST, if both values are less than the current node go left; if both are greater go right; otherwise the current node is the LCA. Time: O(h).

❌ **Wrong — uses a general tree approach on a BST, ignores the sorted property:**
```csharp
public TreeNode LowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
    if (root == null || root == p || root == q) return root;
    var left = LowestCommonAncestor(root.left, p, q);
    var right = LowestCommonAncestor(root.right, p, q);
    if (left != null && right != null) return root;
    return left ?? right;
    // works but doesn't exploit BST ordering — O(n) instead of O(h)
}
```

✅ **Correct — exploits BST ordering, O(h):**
```csharp
public TreeNode LowestCommonAncestor(TreeNode root, TreeNode p, TreeNode q) {
    while (root != null) {
        if (p.val < root.val && q.val < root.val)
            root = root.left;
        else if (p.val > root.val && q.val > root.val)
            root = root.right;
        else
            return root;
    }
    return null;
}
```

---

# 5. Graphs

> 📚 Reference: https://cp-algorithms.com/graph/bfs.html
> 📚 Visual: https://visualgo.net/en/dfsbfs

---

## 5.1 BFS Shortest Path

### Q13. How do you find the shortest path in an unweighted graph?

**Answer:**
BFS guarantees shortest path in unweighted graphs because it explores nodes level by level. Track visited nodes to avoid cycles. Time: O(V+E).

❌ **Wrong — DFS finds a path but not the shortest one:**
```csharp
public int ShortestPath(int[][] graph, int start, int end) {
    // DFS may return a longer path
    bool[] visited = new bool[graph.Length];
    int Dfs(int node, int depth) {
        if (node == end) return depth;
        visited[node] = true;
        foreach (var neighbor in graph[node])
            if (!visited[neighbor]) return Dfs(neighbor, depth + 1);
        return -1;
    }
    return Dfs(start, 0);
}
```

✅ **Correct — BFS guarantees shortest path:**
```csharp
public int ShortestPath(int[][] graph, int start, int end) {
    var visited = new bool[graph.Length];
    var queue = new Queue<(int node, int dist)>();
    queue.Enqueue((start, 0));
    visited[start] = true;
    while (queue.Count > 0) {
        var (node, dist) = queue.Dequeue();
        if (node == end) return dist;
        foreach (var neighbor in graph[node]) {
            if (!visited[neighbor]) {
                visited[neighbor] = true;
                queue.Enqueue((neighbor, dist + 1));
            }
        }
    }
    return -1;
}
```

---

## 5.2 Cycle Detection in Directed Graph

### Q14. How do you detect a cycle in a directed graph?

**Answer:**
Use DFS with three node states: 0 = unvisited, 1 = in current DFS path, 2 = fully processed. If you reach a node in state 1, a cycle exists. Time: O(V+E).

❌ **Wrong — simple visited array doesn't work for directed graphs:**
```csharp
public bool HasCycle(int n, int[][] edges) {
    var visited = new bool[n];
    bool[] adj = BuildAdj(n, edges);
    bool Dfs(int node) {
        visited[node] = true;
        foreach (var neighbor in adj[node])
            if (visited[neighbor] || Dfs(neighbor)) return true; // wrong: visited ≠ in current path
        return false;
    }
    for (int i = 0; i < n; i++)
        if (!visited[i] && Dfs(i)) return true;
    return false;
}
```

✅ **Correct — three-state DFS:**
```csharp
public bool HasCycle(int n, IList<IList<int>> adj) {
    int[] state = new int[n]; // 0=unvisited, 1=in-path, 2=done

    bool Dfs(int node) {
        state[node] = 1;
        foreach (var neighbor in adj[node]) {
            if (state[neighbor] == 1) return true;   // back edge = cycle
            if (state[neighbor] == 0 && Dfs(neighbor)) return true;
        }
        state[node] = 2;
        return false;
    }

    for (int i = 0; i < n; i++)
        if (state[i] == 0 && Dfs(i)) return true;
    return false;
}
```

---

## 5.3 Topological Sort (Kahn's Algorithm)

### Q15. How do you perform topological sort on a DAG?

**Answer:**
Kahn's algorithm: compute in-degrees, enqueue all nodes with in-degree 0, process them and reduce neighbors' in-degrees. If all nodes are processed, no cycle exists. Time: O(V+E).

❌ **Wrong — DFS post-order is correct but hard to detect cycles mid-sort:**
```csharp
// DFS post-order works but doesn't detect cycles cleanly
void Dfs(int node, bool[] visited, Stack<int> stack) {
    visited[node] = true;
    foreach (var n in adj[node])
        if (!visited[n]) Dfs(n, visited, stack);
    stack.Push(node); // added after processing children
}
```

✅ **Correct — Kahn's BFS with in-degree tracking:**
```csharp
public int[] TopologicalSort(int n, int[][] edges) {
    var adj = new List<int>[n].Select(_ => new List<int>()).ToArray();
    int[] inDegree = new int[n];
    foreach (var e in edges) { adj[e[0]].Add(e[1]); inDegree[e[1]]++; }

    var queue = new Queue<int>();
    for (int i = 0; i < n; i++) if (inDegree[i] == 0) queue.Enqueue(i);

    var order = new List<int>();
    while (queue.Count > 0) {
        int node = queue.Dequeue();
        order.Add(node);
        foreach (var neighbor in adj[node])
            if (--inDegree[neighbor] == 0) queue.Enqueue(neighbor);
    }
    return order.Count == n ? order.ToArray() : Array.Empty<int>(); // empty = cycle detected
}
```

---

# 6. Sorting & Searching

> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/api/system.array.sort
> 📚 Sorting visualizer: https://visualgo.net/en/sorting

---

## 6.1 Binary Search

### Q16. How do you implement binary search correctly?

**Answer:**
Requires a sorted array. Compare target to the middle element. Halve the search space each iteration. Common bug: integer overflow when computing mid — use `left + (right - left) / 2`. Time: O(log n).

❌ **Wrong — integer overflow risk on large arrays:**
```csharp
public int BinarySearch(int[] nums, int target) {
    int left = 0, right = nums.Length - 1;
    while (left <= right) {
        int mid = (left + right) / 2; // overflow if left + right > int.MaxValue
        if (nums[mid] == target) return mid;
        if (nums[mid] < target) left = mid + 1;
        else right = mid - 1;
    }
    return -1;
}
```

✅ **Correct — overflow-safe mid calculation:**
```csharp
public int BinarySearch(int[] nums, int target) {
    int left = 0, right = nums.Length - 1;
    while (left <= right) {
        int mid = left + (right - left) / 2; // safe
        if (nums[mid] == target) return mid;
        if (nums[mid] < target) left = mid + 1;
        else right = mid - 1;
    }
    return -1;
}
```

---

## 6.2 Quick Sort

### Q17. How does Quick Sort work and what is its weakness?

**Answer:**
Quick Sort picks a pivot, partitions elements smaller/larger around it, and recurses. Average O(n log n). Worst case O(n²) when the pivot is always the min/max (already sorted array). Mitigated by random pivot selection.

❌ **Wrong — always picks first element as pivot, O(n²) on sorted input:**
```csharp
void QuickSort(int[] arr, int low, int high) {
    if (low < high) {
        int pivot = arr[low]; // bad choice on sorted arrays
        int i = low + 1;
        for (int j = low + 1; j <= high; j++)
            if (arr[j] < pivot) { Swap(arr, i, j); i++; }
        Swap(arr, low, i - 1);
        QuickSort(arr, low, i - 2);
        QuickSort(arr, i, high);
    }
}
```

✅ **Correct — randomized pivot to avoid worst case:**
```csharp
private Random _rand = new Random();

void QuickSort(int[] arr, int low, int high) {
    if (low < high) {
        int pivotIdx = _rand.Next(low, high + 1);
        Swap(arr, pivotIdx, high); // move pivot to end
        int pivot = arr[high];
        int i = low - 1;
        for (int j = low; j < high; j++)
            if (arr[j] <= pivot) { i++; Swap(arr, i, j); }
        Swap(arr, i + 1, high);
        int pi = i + 1;
        QuickSort(arr, low, pi - 1);
        QuickSort(arr, pi + 1, high);
    }
}
```

---

# 7. Dynamic Programming

> 📚 Reference: https://leetcode.com/explore/learn/card/dynamic-programming/
> 📚 Patterns: https://leetcode.com/discuss/general-discussion/458695/dynamic-programming-patterns

---

## 7.1 Fibonacci — Memoization vs Tabulation

### Q18. What is the difference between top-down (memoization) and bottom-up (tabulation) DP?

**Answer:**
Memoization is recursive with a cache — compute subproblems only when needed. Tabulation is iterative — fill a table from base cases up. Tabulation avoids stack overflow and is usually more space-efficient.

❌ **Wrong — naive recursion, exponential O(2^n) time:**
```csharp
public int Fib(int n) {
    if (n <= 1) return n;
    return Fib(n - 1) + Fib(n - 2); // recomputes same values repeatedly
}
```

✅ **Correct — tabulation, O(n) time, O(1) space:**
```csharp
public int Fib(int n) {
    if (n <= 1) return n;
    int prev2 = 0, prev1 = 1;
    for (int i = 2; i <= n; i++) {
        int curr = prev1 + prev2;
        prev2 = prev1;
        prev1 = curr;
    }
    return prev1;
}
```

---

## 7.2 0/1 Knapsack

### Q19. How do you solve the 0/1 Knapsack problem?

**Answer:**
`dp[w]` = max value achievable with capacity `w`. Iterate items outer, capacity inner (reverse to avoid using item twice). Time: O(n×W), Space: O(W).

❌ **Wrong — forward inner loop allows using same item multiple times (unbounded knapsack):**
```csharp
for (int i = 0; i < n; i++)
    for (int w = weights[i]; w <= capacity; w++) // forward = unbounded
        dp[w] = Math.Max(dp[w], dp[w - weights[i]] + values[i]);
```

✅ **Correct — reverse inner loop for 0/1 constraint:**
```csharp
public int Knapsack(int[] weights, int[] values, int capacity) {
    int n = weights.Length;
    int[] dp = new int[capacity + 1];
    for (int i = 0; i < n; i++)
        for (int w = capacity; w >= weights[i]; w--) // reverse = use each item at most once
            dp[w] = Math.Max(dp[w], dp[w - weights[i]] + values[i]);
    return dp[capacity];
}
```

---

## 7.3 Coin Change

### Q20. How do you find the minimum number of coins to reach a target amount?

**Answer:**
Bottom-up DP: `dp[i]` = min coins for amount `i`. For each amount, try each coin. Initialize to infinity, `dp[0] = 0`. Time: O(amount × coins).

❌ **Wrong — greedy fails for non-standard denominations (e.g., coins = [1,3,4], amount = 6, greedy gives 3 coins, optimal is 2):**
```csharp
public int CoinChange(int[] coins, int amount) {
    Array.Sort(coins, (a, b) => b - a); // sort descending
    int count = 0;
    foreach (int coin in coins) {
        count += amount / coin;
        amount %= coin;
    }
    return amount == 0 ? count : -1;
}
```

✅ **Correct — bottom-up DP:**
```csharp
public int CoinChange(int[] coins, int amount) {
    int[] dp = new int[amount + 1];
    Array.Fill(dp, amount + 1); // use amount+1 as "infinity"
    dp[0] = 0;
    for (int i = 1; i <= amount; i++)
        foreach (int coin in coins)
            if (coin <= i)
                dp[i] = Math.Min(dp[i], dp[i - coin] + 1);
    return dp[amount] > amount ? -1 : dp[amount];
}
```

---

# 8. Two Pointers & Sliding Window

> 📚 Reference: https://leetcode.com/explore/learn/card/array-and-string/205/array-two-pointer-technique/
> 📚 Patterns: https://medium.com/leetcode-patterns/leetcode-pattern-2-sliding-windows-for-strings-e19af105316b

---

## 8.1 Longest Substring Without Repeating Characters

### Q21. How do you find the longest substring without repeating characters?

**Answer:**
Sliding window with a HashSet. Expand right; if duplicate found, shrink from left until duplicate is removed. Track max window size. Time: O(n).

❌ **Wrong — O(n²) substring generation:**
```csharp
public int LengthOfLongestSubstring(string s) {
    int max = 0;
    for (int i = 0; i < s.Length; i++) {
        var seen = new HashSet<char>();
        for (int j = i; j < s.Length; j++) {
            if (!seen.Add(s[j])) break;
            max = Math.Max(max, j - i + 1);
        }
    }
    return max;
}
```

✅ **Correct — O(n) sliding window:**
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

# 9. Recursion & Backtracking

> 📚 Reference: https://leetcode.com/explore/learn/card/recursion-ii/470/divide-and-conquer/
> 📚 Patterns: https://medium.com/leetcode-patterns/leetcode-pattern-3-backtracking-4d7e7a0ef93

---

## 9.1 Generate All Subsets

### Q22. How do you generate all subsets (power set) of an array?

**Answer:**
Backtracking: at each index, include or exclude the element and recurse. Time: O(2^n × n), Space: O(n) recursion depth.

❌ **Wrong — bit manipulation works but is harder to read and extend (e.g., for subset sum constraints):**
```csharp
public IList<IList<int>> Subsets(int[] nums) {
    int n = nums.Length;
    var result = new List<IList<int>>();
    for (int mask = 0; mask < (1 << n); mask++) {
        var subset = new List<int>();
        for (int i = 0; i < n; i++)
            if ((mask & (1 << i)) != 0) subset.Add(nums[i]);
        result.Add(subset);
    }
    return result; // correct but inflexible for variants
}
```

✅ **Correct — backtracking, easily extended to handle constraints:**
```csharp
public IList<IList<int>> Subsets(int[] nums) {
    var result = new List<IList<int>>();
    Backtrack(nums, 0, new List<int>(), result);
    return result;
}

private void Backtrack(int[] nums, int start, List<int> current, IList<IList<int>> result) {
    result.Add(new List<int>(current)); // add a copy of current subset
    for (int i = start; i < nums.Length; i++) {
        current.Add(nums[i]);
        Backtrack(nums, i + 1, current, result);
        current.RemoveAt(current.Count - 1); // undo choice
    }
}
```

---

# 10. Complexity Analysis

> 📚 Reference: https://www.bigocheatsheet.com/
> 📚 Reference: https://learn.microsoft.com/en-us/dotnet/standard/collections/selecting-a-collection-class

---

## 10.1 Big O Notation

### Q23. What is Big O notation and how do you analyze time complexity?

**Answer:**
Big O describes the upper bound on an algorithm's growth rate as input size n grows. Drop constants and lower-order terms. Analyze loops: single loop = O(n), nested loops = O(n²), halving each iteration = O(log n), halving with inner loop = O(n log n).

❌ **Wrong — incorrectly states O(n²) for this code due to not analyzing carefully:**
```csharp
// Is this O(n²)?
for (int i = 0; i < n; i++)           // O(n)
    for (int j = i; j < n; j++)       // O(n-i) — still O(n²) total iterations
        Console.Write(arr[i] + arr[j]);
// Total pairs: n(n+1)/2 → O(n²) ✓ — but easy to misread as O(n log n)
```

✅ **Correct — identifying the pattern for common complexities:**
```
O(1)        — array index, hash map lookup (avg)
O(log n)    — binary search, BST operation (balanced)
O(n)        — single loop, linear scan
O(n log n)  — merge sort, heap sort, efficient sort
O(n²)       — nested loops over same input
O(2^n)      — subsets, many backtracking problems
O(n!)       — all permutations
```

---

## 10.2 Amortized Analysis

### Q24. What does amortized O(1) mean? Give an example.

**Answer:**
Amortized analysis averages the cost over a sequence of operations. A `List<T>` has amortized O(1) `Add` — most adds are O(1), but occasional doubling resizes are O(n). Spread over n adds, the total work is O(n), so average is O(1) per add.

❌ **Wrong — using `LinkedList<T>` when `List<T>` amortized append is sufficient:**
```csharp
// LinkedList has O(1) append but O(n) index access and poor cache locality
var list = new LinkedList<int>();
for (int i = 0; i < n; i++) list.AddLast(i);
int val = list.ElementAt(500); // O(n) traversal to index
```

✅ **Correct — `List<T>` for sequential append + index access:**
```csharp
var list = new List<int>();
for (int i = 0; i < n; i++) list.Add(i); // amortized O(1) per add
int val = list[500]; // O(1) index access
```
