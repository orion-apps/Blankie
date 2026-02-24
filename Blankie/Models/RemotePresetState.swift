import Foundation

struct RemotePresetState: Codable, Equatable {
  let remoteID: String
  let isSelected: Bool
  let volume: Float
  let pan: Float
}
