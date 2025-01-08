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

struct SettingView: View {
    
    let store: StoreOf<Setting>
    
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
                    
                    Text("Settings")
                    
                    Spacer()
                }
            }
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
