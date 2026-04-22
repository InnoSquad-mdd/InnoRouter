import InnoRouterCore

internal enum SceneDispatchPlan<R: Route>: Equatable {
    case openWindow(id: String, presentation: ScenePresentation<R>)
    case openImmersive(id: String, presentation: ScenePresentation<R>)
    case dismissWindow(id: String, presentation: ScenePresentation<R>)
    case dismissImmersive(presentation: ScenePresentation<R>)
    case reject(SceneIntent<R>, reason: SceneRejectionReason)
}

internal struct SceneIntentResolver<R: Route> {
    internal let scenes: SceneRegistry<R>

    internal init(scenes: SceneRegistry<R>) {
        self.scenes = scenes
    }

    internal func resolve(
        _ intent: SceneIntent<R>,
        state: SceneStoreSnapshot<R>
    ) -> SceneDispatchPlan<R> {
        switch intent {
        case .open(let presentation):
            resolveOpen(presentation)
        case .dismissImmersive:
            resolveDismissImmersive(state: state)
        case .dismissWindow(let route):
            resolveDismissWindow(route, state: state)
        }
    }

    private func resolveOpen(
        _ presentation: ScenePresentation<R>
    ) -> SceneDispatchPlan<R> {
        let intent = SceneIntent<R>.open(presentation)

        guard let declaration = scenes.declaration(for: presentation.route) else {
            return .reject(intent, reason: .sceneNotDeclared)
        }
        guard declaration.matches(presentation) else {
            return .reject(intent, reason: .sceneDeclarationMismatch)
        }

        switch presentation {
        case .window, .volumetric:
            return .openWindow(id: declaration.id, presentation: presentation)
        case .immersive:
            return .openImmersive(id: declaration.id, presentation: presentation)
        }
    }

    private func resolveDismissImmersive(
        state: SceneStoreSnapshot<R>
    ) -> SceneDispatchPlan<R> {
        let intent = SceneIntent<R>.dismissImmersive

        guard let activeImmersive = state.activeImmersive else {
            return .reject(
                intent,
                reason: state.hasActiveScenes ? .activeSceneMismatch : .nothingActive
            )
        }
        guard let declaration = scenes.declaration(for: activeImmersive.route) else {
            return .reject(intent, reason: .sceneNotDeclared)
        }
        guard declaration.matches(activeImmersive) else {
            return .reject(intent, reason: .sceneDeclarationMismatch)
        }

        return .dismissImmersive(presentation: activeImmersive)
    }

    private func resolveDismissWindow(
        _ route: R,
        state: SceneStoreSnapshot<R>
    ) -> SceneDispatchPlan<R> {
        let intent = SceneIntent<R>.dismissWindow(route)

        guard let activeWindow = state.windowPresentation(for: route) else {
            return .reject(
                intent,
                reason: state.hasActiveScenes ? .activeSceneMismatch : .nothingActive
            )
        }
        guard let declaration = scenes.declaration(for: route) else {
            return .reject(intent, reason: .sceneNotDeclared)
        }
        guard declaration.matches(activeWindow) else {
            return .reject(intent, reason: .sceneDeclarationMismatch)
        }

        return .dismissWindow(id: declaration.id, presentation: activeWindow)
    }
}
