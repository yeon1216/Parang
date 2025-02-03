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
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    if let player = viewStore.player {
                        MetalVideoView(player: player)
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

#Preview {
    ParangEditorView(
        store: Store(initialState: ParangEditor.State()) {
            ParangEditor()
        }
    )
}
