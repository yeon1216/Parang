//
//  HomeView.swift
//  Parang
//
//  Created by BOBBY.KIM on 11/18/24.
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct Home {
    struct State: Equatable {
        var loading = false
    }
    
    enum Action {
        case onAppear
        case tapSetting
    }
    
    @Dependency(\.continuousClock) var clock
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return .none
        case .tapSetting:
            return .none
        }
        
    }
    
}

struct HomeView: View {
    
    let store: StoreOf<Home>
    @State private var appeared = false
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                //                Color.nenioWhite.ignoresSafeArea(.all)
                Text("Home")
            }
            .ignoresSafeArea(.all)
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: Home.State())
        {
            Home()
        }
    )
}
