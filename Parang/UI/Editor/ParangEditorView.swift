import SwiftUI
import ComposableArchitecture
import AVKit
import PhotosUI

@Reducer
struct ParangEditor {
    struct State: Equatable {
        var selectedVideo: URL?
        var player: AVPlayer?
        var isLoading = false
        
        init(selectedVideo: URL? = nil) {
            self.selectedVideo = selectedVideo
            if let url = selectedVideo {
                self.player = AVPlayer(url: url)
            }
        }
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedVideo == rhs.selectedVideo
        }
    }
    
    enum Action {
        case onAppear
        case tapBack
        case videoPlayerOnAppear
        case videoPlayerOnDisappear
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .none
                
            case .tapBack:
                return .none
                
            case .videoPlayerOnAppear:
                state.player?.play()
                state.isLoading = false
                
                return .none
                
            case .videoPlayerOnDisappear:
                state.player?.pause()
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
                    // Video Preview
                    if let player = viewStore.player {
                        VideoPlayer(player: player)
                            .onAppear {
                                viewStore.send(.videoPlayerOnAppear)
                            }
                            .onDisappear {
                                viewStore.send(.videoPlayerOnDisappear)
                            }
                    }
                }
                
                if viewStore.isLoading {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
                
                // Navigation Bar
                VStack {
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
                    Spacer()
                }

            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewStore.send(.onAppear)
            }
        }
    }
}

struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentDirectory.appendingPathComponent("video-\(UUID().uuidString).mov")
            
            // 이미 파일이 있다면 삭제
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // 데이터 저장
            try data.write(to: destinationURL)
            return Movie(url: destinationURL)
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
