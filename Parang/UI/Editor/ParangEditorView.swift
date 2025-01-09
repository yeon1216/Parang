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
            let videoDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("videos")
            
            // videos 디렉토리가 없다면 생성
            if !FileManager.default.fileExists(atPath: videoDirectory.path) {
                try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
            }
            
            let videoURL = videoDirectory.appendingPathComponent("video-\(UUID().uuidString).mov")
            print("로그 ::: transferRepresentation videoURL: \(videoURL)")
            
            // 이미 파일이 있다면 삭제
            if FileManager.default.fileExists(atPath: videoURL.path) {
                try FileManager.default.removeItem(at: videoURL)
            }
            
            // 데이터를 임시 파일로 저장
            let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try data.write(to: temporaryURL)
            
            do {
                // 임시 파일을 최종 위치로 이동
                try FileManager.default.moveItem(at: temporaryURL, to: videoURL)
                print("로그 ::: 파일 이동 성공")
            } catch {
                print("로그 ::: 파일 이동 실패:", error)
                // 이동 실패시 데이터를 직접 쓰기
                try data.write(to: videoURL)
            }
            
            return Movie(url: videoURL)
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
