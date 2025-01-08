import SwiftUI
import ComposableArchitecture
import PhotosUI

@Reducer
struct ParangVideoPicker {
    struct State: Equatable {
        var selectedVideo: PhotosPickerItem?
        var isLoading = false
    }
    
    enum Action {
        case onAppear
        case tapBack
        case videoSelected(PhotosPickerItem?)
        case proceedToEditor(URL?)
        case setLoading(Bool)
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
                    if let item {
                        if let videoURL = try? await item.loadTransferable(type: VideoURL.self) {
                            await send(.proceedToEditor(videoURL.url))
                        } else {
                            await send(.proceedToEditor(nil))
                        }
                    }
                    await send(.setLoading(false))
                }
                
            case .proceedToEditor:
                return .none
                
            case let .setLoading(isLoading):
                state.isLoading = isLoading
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