import SwiftUI
import SCard

struct ViewPresenter: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { return view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    return VStack {
        let view = UILabel()
        view.text = "Hi"
        view.textAlignment = .center
        return ViewPresenter(view: view)
    }
}
