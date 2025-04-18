//
//  RootView.swift
//  Parang
//
//  Created by BOBBY.KIM on 11/18/24.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct Root {
    
    struct State: Equatable {
        var path = StackState<Path.State>()
    }
    
    enum Action {
        case goBackToScreen(id: StackElementID)
        case path(StackAction<Path.State, Path.Action>)
        case popToRoot
    }
    
    var body: some Reducer<State, Action> {
        
        Reduce { state, action in
            switch action {
            case let .goBackToScreen(id):
                state.path.pop(to: id)
                return .none
            case .popToRoot:
                state.path.removeAll()
                return .none
            case let .path(pathAction):
                switch pathAction {
                case .element(id: _, action: .screenHome(.tapSetting)):
                    state.path.append(.screenSetting())
                    return .none
                case .element(id: _, action: .screenHome(.tapCamera)):
                    state.path.append(.screenCamera())
                    return .none
                case .element(id: _, action: .screenHome(.tapEditor)):
                    state.path.append(.screenVideoPicker())
                    return .none
                case .element(id: _, action: .screenSetting(.tapBack)):
                    state.path.removeLast()
                    return .none
                case .element(id: _, action: .screenCamera(.tapBack)):
                    state.path.removeLast()
                    return .none
                case .element(id: _, action: .screenEditor(.tapBack)):
                    state.path.removeLast()
                    return .none
                case .element(id: _, action: .screenVideoPicker(.tapBack)):
                    state.path.removeLast()
                    return .none
                case .element(id: _, action: .screenVideoPicker(.proceedToEditor(let url))):
                    if let url {
                        state.path.append(.screenEditor(ParangEditor.State(selectedVideo: url)))
                    }
                    return .none
                default:
                    return .none
                }
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
    
    // Navigation Reference
    // Sample App : https://github.com/pointfreeco/swift-composable-architecture/tree/main/Examples/CaseStudies
    // Reference : https://www.pointfree.co/blog/posts/106-navigation-tools-come-to-the-composable-architecture
    @Reducer
    struct Path {
        enum State: Equatable {
            case screenHome(Home.State = .init())
            case screenSetting(Setting.State = .init())
            case screenCamera(ParangCamera.State = .init())
            case screenEditor(ParangEditor.State = .init())
            case screenVideoPicker(ParangVideoPicker.State = .init())
        }
        
        enum Action {
            case screenHome(Home.Action)
            case screenSetting(Setting.Action)
            case screenCamera(ParangCamera.Action)
            case screenEditor(ParangEditor.Action)
            case screenVideoPicker(ParangVideoPicker.Action)
        }
        
        var body: some Reducer<State, Action> {
            Scope(state: \.screenHome, action: \.screenHome) {
                Home()
            }
            Scope(state: \.screenSetting, action: \.screenSetting) {
                Setting()
            }
            Scope(state: \.screenCamera, action: \.screenCamera) {
                ParangCamera()
            }
            Scope(state: \.screenEditor, action: \.screenEditor) {
                ParangEditor()
            }
            Scope(state: \.screenVideoPicker, action: \.screenVideoPicker) {
                ParangVideoPicker()
            }
        }
    }
    
}

struct RootView: View {
    
    let store: StoreOf<Root>
    
    var body: some View {
        NavigationStackStore(
            self.store.scope(
                state: \.path,
                action: {
                    .path($0)
                }
            )
        ) {
            HomeView(
                store: Store(initialState: Home.State())
                {
                    Home()
                }
            )
        } destination: { store in
            switch store {
            case .screenHome:
                CaseLet(
                    /Root.Path.State.screenHome,
                     action: Root.Path.Action.screenHome,
                     then: HomeView.init(store:)
                )
            case .screenSetting:
                CaseLet(
                    /Root.Path.State.screenSetting,
                     action: Root.Path.Action.screenSetting,
                     then: { SettingView(store: $0) }
                )
            case .screenCamera:
                CaseLet(
                    /Root.Path.State.screenCamera,
                    action: Root.Path.Action.screenCamera,
                    then: ParangCameraView.init(store:)
                )
            case .screenEditor:
                CaseLet(
                    /Root.Path.State.screenEditor,
                    action: Root.Path.Action.screenEditor,
                    then: ParangEditorView.init(store:)
                )
            case .screenVideoPicker:
                CaseLet(
                    /Root.Path.State.screenVideoPicker,
                    action: Root.Path.Action.screenVideoPicker,
                    then: ParangVideoPickerView.init(store:)
                )
            }
        }
    }
}
