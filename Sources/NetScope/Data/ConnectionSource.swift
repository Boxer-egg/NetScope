import Foundation

protocol ConnectionSource: AnyObject {
    var onUpdate: (([Connection]) -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }
    var pollInterval: TimeInterval { get set }
    func start()
    func stop()
    var displayName: String { get }
}
