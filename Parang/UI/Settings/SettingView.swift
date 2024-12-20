//
//  SettingView.swift
//  Parang
//
//  Created by BOBBY.KIM on 11/18/24.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct Setting {
    struct State: Equatable {
        var loading = false
    }
    
    enum Action {
        case onAppear
    }
    
    @Dependency(\.continuousClock) var clock
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .none
        }
        
    }
    
}

struct SettingView: View {
    
    let store: StoreOf<Setting>
    @State private var appeared = false
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
//                Color.nenioWhite.ignoresSafeArea(.all)
                Image("ic_nenio_characters")
                    .renderingMode(.original)
                    .resizable()
                    .frame(width: 184, height: 172.8)
                    .onAppear {
                        guard !appeared else { return }
                        appeared = true
                        viewStore.send(.onAppear)
                    }
            }
            .ignoresSafeArea(.all)
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    SettingView(
        store: Store(initialState: Setting.State())
        {
            Setting()
        }
    )
}
