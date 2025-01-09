import SwiftUI
import ComposableArchitecture
import PhotosUI
import UniformTypeIdentifiers

@Reducer
struct ParangVideoPicker {
    struct State: Equatable {
        var selectedVideo: PhotosPickerItem?
        var isLoading = false
        var showError = false
        var errorMessage = ""
    }
    
    enum Action {
        case onAppear
        case tapBack
        case videoSelected(PhotosPickerItem?)
        case proceedToEditor(URL?)
        case setLoading(Bool)
        case setError(message: String)
        case dismissError
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .tapBack:
                return .none
                
            case let .videoSelected(item):
                state.selectedVideo = item
                state.isLoading = true
                
                return .run { [item] send in
                    guard let item else { 
                        await send(.setLoading(false))
                        return 
                    }
                    
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    
                    var isAuthorized: Bool = false
                    
                    if status == .notDetermined {
                        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                        if granted == .authorized {
                            isAuthorized = true
                        } else {
                            isAuthorized = false
                        }
                    }
                    
                    do {
                        if status == .authorized || isAuthorized {
                            let movie = try await item.loadTransferable(type: VideoURL.self)
                            if let movie {
                                await send(.proceedToEditor(movie.url))
                            } else {
                                await send(.setError(message: "Failed to copy video."))
                            }
                        } else {
                            let movie = try await item.loadTransferable(type: Movie.self)
                            if let movie {
                                await send(.proceedToEditor(movie.url))
                            } else {
                                await send(.setError(message: "Failed to load video. Please try a different video."))
                            }
                        }
                    } catch {
                        print("Video loading error:", error)
                        await send(.setError(message: error.localizedDescription))
                    }
                    await send(.setLoading(false))
                }
                
            case .proceedToEditor:
                return .none
                
            case let .setLoading(isLoading):
                state.isLoading = isLoading
                return .none
                
            case let .setError(message):
                state.showError = true
                state.errorMessage = message
                return .none
                
            case .dismissError:
                state.showError = false
                state.errorMessage = ""
                return .none
            }
        }
    }
}

struct ParangVideoPickerView: View {
    let store: StoreOf<ParangVideoPicker>
    @State private var photosPickerItem: PhotosPickerItem?
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
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
                    
                    Spacer()
                    
                    // Content
                    VStack(spacing: 30) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Select a video to edit")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        PhotosPicker(
                            selection: $photosPickerItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose from Library")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 200)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .onChange(of: photosPickerItem) { _, newValue in
                            viewStore.send(.videoSelected(newValue))
                        }
                    }
                    
                    Spacer()
                }
                
                if viewStore.isLoading {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .navigationBarBackButtonHidden(true)
            .alert(
                "Error",
                isPresented: viewStore.binding(
                    get: \.showError,
                    send: { _ in .dismissError }
                )
            ) {
                Button("OK") {
                    viewStore.send(.dismissError)
                }
            } message: {
                Text(viewStore.errorMessage)
            }
        }
    }
}

#Preview {
    ParangVideoPickerView(
        store: Store(initialState: ParangVideoPicker.State()) {
            ParangVideoPicker()
        }
    )
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

struct VideoURL: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let videoDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("videos")
            let videoURL = videoDirectory.appendingPathComponent("video-\(UUID().uuidString).mov")
            
            // 이미 파일이 있다면 삭제
            if FileManager.default.fileExists(atPath: videoURL.path) {
                try FileManager.default.removeItem(at: videoURL)
            }
            
            // 파일 복사
            try FileManager.default.copyItem(at: received.file, to: videoURL)
            
            return Self.init(url: videoURL)
        }
    }
}
