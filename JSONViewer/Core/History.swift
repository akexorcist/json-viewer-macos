import Foundation

// MARK: - History (undo / redo stack)

final class History<T> {
    private var undoStack: [T] = []
    private var redoStack: [T] = []
    private let maxSize: Int

    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func push(_ state: T) {
        undoStack.append(state)
        if undoStack.count > maxSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo(current: T) -> T? {
        guard canUndo else { return nil }
        redoStack.append(current)
        return undoStack.removeLast()
    }

    func redo(current: T) -> T? {
        guard canRedo else { return nil }
        undoStack.append(current)
        return redoStack.removeLast()
    }

    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
