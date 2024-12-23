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
                case .element(id: _, action: .screenSetting(.tapBack)):
                    state.path.removeLast()
                    return .none
                case .element(id: _, action: .screenCamera(.tapBack)):
                    state.path.removeLast()
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
        }
        
        enum Action {
            case screenHome(Home.Action)
            case screenSetting(Setting.Action)
            case screenCamera(ParangCamera.Action)
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
            }
        }
    }
}
