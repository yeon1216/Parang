import SwiftUI
import ComposableArchitecture
import AVKit
import PhotosUI

@Reducer
struct ParangEditor {
    struct State: Equatable {
        var selectedVideo: URL?
        var isVideoPickerPresented = false
        var player: AVPlayer?
        
        init(selectedVideo: URL? = nil) {
            self.selectedVideo = selectedVideo
            if let url = selectedVideo {
                self.player = AVPlayer(url: url)
            }
        }
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedVideo == rhs.selectedVideo &&
            lhs.isVideoPickerPresented == rhs.isVideoPickerPresented
        }
    }
    
    enum Action {
        case onAppear
        case tapBack
        case tapSelectVideo
        case videoSelected(URL?)
        case setVideoPickerPresented(Bool)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .tapBack:
                return .none
                
            case .tapSelectVideo:
                state.isVideoPickerPresented = true
                return .none
                
            case let .videoSelected(url):
                state.selectedVideo = url
                if let url {
                    state.player = AVPlayer(url: url)
                } else {
                    state.player = nil
                }
                return .none
                
            case let .setVideoPickerPresented(isPresented):
                state.isVideoPickerPresented = isPresented
                return .none
            }
        }
    }
}

struct ParangEditorView: View {
    let store: StoreOf<ParangEditor>
    @State private var photosPickerItem: PhotosPickerItem?
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Navigation Bar
                    HStack {
                        Button(action: { viewStore.send(.tapBack) }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 20, weight: .bold))
                                .padding()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Video Preview
                    if let player = viewStore.player {
                        VideoPlayer(player: player)
                            .onAppear {
                                player.play()
                            }
                            .onDisappear {
                                player.pause()
                            }
                    } else {
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .padding()
                            
                            Text("No video selected")
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Bottom Controls
                    HStack {
                        PhotosPicker(
                            selection: $photosPickerItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            Text("Select Video")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .onChange(of: photosPickerItem) { _, newValue in
                            Task {
                                if let newValue {
                                    if let videoURL = try? await newValue.loadTransferable(type: VideoURL.self) {
                                        await MainActor.run {
                                            viewStore.send(.videoSelected(videoURL.url))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

// Helper struct to load video URL from PhotosPickerItem
struct VideoURL: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video-\(UUID().uuidString).mov")
            
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}

#Preview {
    ParangEditorView(
        store: Store(initialState: ParangEditor.State()) {
            ParangEditor()
        }
    )
} 