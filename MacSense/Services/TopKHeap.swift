import Foundation

/// Min-heap over `CleanableItem.size`, capped at `cap` entries.
/// Insertion is O(log cap) and rejects items smaller than the current
/// minimum without doing extra work — much cheaper than maintaining a
/// sorted list with append + sort on every file.
struct TopKHeap {
    let cap: Int
    private var heap: [CleanableItem] = []

    init(cap: Int) {
        self.cap = cap
        heap.reserveCapacity(cap + 1)
    }

    func wouldAccept(size: Int64) -> Bool {
        if heap.count < cap { return true }
        return size > heap[0].size
    }

    mutating func insert(_ item: CleanableItem) {
        if heap.count < cap {
            heap.append(item)
            siftUp(from: heap.count - 1)
        } else if item.size > heap[0].size {
            heap[0] = item
            siftDown(from: 0)
        }
    }

    func sortedDescending() -> [CleanableItem] {
        heap.sorted { $0.size > $1.size }
    }

    private mutating func siftUp(from index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            if heap[i].size < heap[parent].size {
                heap.swapAt(i, parent)
                i = parent
            } else {
                break
            }
        }
    }

    private mutating func siftDown(from index: Int) {
        var i = index
        let n = heap.count
        while true {
            let l = 2 * i + 1
            let r = 2 * i + 2
            var smallest = i
            if l < n && heap[l].size < heap[smallest].size { smallest = l }
            if r < n && heap[r].size < heap[smallest].size { smallest = r }
            if smallest == i { break }
            heap.swapAt(i, smallest)
            i = smallest
        }
    }
}
