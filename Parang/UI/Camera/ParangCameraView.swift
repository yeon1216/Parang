import SwiftUI
import ComposableArchitecture

@Reducer
struct ParangCamera {
    struct State: Equatable {
    }
    
    enum Action {
        case onAppear
        case tapBack
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .none
        case .tapBack:
            return .none
        }
    }
}

struct ParangCameraView: View {
    let store: StoreOf<ParangCamera>
    @State private var appeared = false
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                VStack {
                    HStack {
                        Button(action: {
                            viewStore.send(.tapBack)
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                                .imageScale(.large)
                        }
                        .padding()
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text("Camera")
                    
                    Spacer()
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    ParangCameraView(
        store: Store(initialState: ParangCamera.State())
        {
            ParangCamera()
        }
    )
} 