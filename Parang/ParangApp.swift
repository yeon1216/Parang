//
//  ParangApp.swift
//  Parang
//
//  Created by BOBBY.KIM on 11/18/24.
//

import SwiftUI
import ComposableArchitecture

@main
struct ParangApp: App {
    
    var body: some Scene {
        WindowGroup {
            RootView(
                store: Store(
                    initialState: Root.State(
                        path: StackState([.screenHome()])
                    )
                ) {
                    Root()
                }
            )
        }
    }
}
