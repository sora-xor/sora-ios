import SoraUI

extension ModalInputPresentationHeaderStyle {

    static var modalHeaderStyle: ModalInputPresentationHeaderStyle {
        let indicatorColor = UIColor(white: 208.0 / 255.0, alpha: 1.0)
        return ModalInputPresentationHeaderStyle(preferredHeight: 20.0,
                                                 backgroundColor: .white,
                                                 cornerRadius: 10.0,
                                                 indicatorVerticalOffset: 3.0,
                                                 indicatorSize: CGSize(width: 35, height: 5.0),
                                                 indicatorColor: indicatorColor)
    }
}

extension ModalInputPresentationConfiguration {
    static var sora: ModalInputPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(duration: 0.25,
                                                   delay: 0.0,
                                                   options: [.curveEaseOut])
        let dismissalAnimator = BlockViewAnimator(duration: 0.25,
                                                  delay: 0.0,
                                                  options: [.curveLinear])

        let style = ModalInputPresentationStyle(backdropColor: UIColor.black.withAlphaComponent(0.19),
                                                headerStyle: ModalInputPresentationHeaderStyle.modalHeaderStyle)

        return ModalInputPresentationConfiguration(contentAppearanceAnimator: appearanceAnimator,
                                                                contentDissmisalAnimator: dismissalAnimator,
                                                                style: style,
                                                                extendUnderSafeArea: true,
                                                                dismissFinishSpeedFactor: 0.6,
                                                                dismissCancelSpeedFactor: 0.6)
    }
}
