public indirect enum NavCommand<R: Route>: Sendable, Equatable {
    case push(R)
    case pushAll([R])
    case pop
    case popCount(Int)
    case popToRoot
    case popTo(R)
    case replace([R])
    case conditional(@Sendable () -> Bool, NavCommand<R>)
    case sequence([NavCommand<R>])

    public static func == (lhs: NavCommand<R>, rhs: NavCommand<R>) -> Bool {
        switch (lhs, rhs) {
        case (.push(let l), .push(let r)): l == r
        case (.pushAll(let l), .pushAll(let r)): l == r
        case (.pop, .pop): true
        case (.popCount(let l), .popCount(let r)): l == r
        case (.popToRoot, .popToRoot): true
        case (.popTo(let l), .popTo(let r)): l == r
        case (.replace(let l), .replace(let r)): l == r
        case (.sequence(let l), .sequence(let r)): l == r
        case (.conditional, .conditional): false
        default: false
        }
    }
}
