import Foundation

protocol ConnectionSource: AnyObject {
    var onUpdate: (([Connection]) -> Void)? { get set }
    func start()
    func stop()
    var displayName: String { get }
}
