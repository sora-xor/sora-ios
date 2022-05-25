import UIKit

public protocol PinSymbolsViewProtocol: AnyObject {
    var numberOfCharacters: Int { get set }
    var isComplete: Bool { get }
    var isEmpty: Bool { get }

    func clear()
    func set(newCharacters: [Character])
    func append(character: Character)
    func removeLastCharacter()
    func allCharacters() -> [Character]
}

public class NeuPinSymbolsView: UIView & PinSymbolsViewProtocol {

    @IBOutlet private var containerView: UIView!
    private(set) public var characters: [Character] = [Character]()
    @IBOutlet var symbolImages: [UIImageView]!

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initNib()
    }

    func initNib() {
        backgroundColor = .clear

        let bundle = Bundle(for: NeuPinSymbolsView.self)
        bundle.loadNibNamed("NeuPinSymbolsView", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        setup()
    }

    func setup() {
        self.contentMode = .scaleAspectFit
    }

    open override var intrinsicContentSize: CGSize {
        let width = UIScreen.main.bounds.width - 58
        let height = width * 0.53517 //TODO: remove this magic number aspect ratio
        return CGSize(width: width, height: height)
    }

    public var numberOfCharacters: Int = 4

    open var isComplete: Bool {
        return characters.count == numberOfCharacters
    }

    open var isEmpty: Bool {
        return characters.count == 0
    }

    open func clear() {
        characters.removeAll()
        setupImage()
    }

    open func set(newCharacters: [Character]) {
        let count = min(newCharacters.count, numberOfCharacters)
        characters = Array(newCharacters[..<count])
        setupImage()
    }

    open func append(character: Character) {
        if characters.count < numberOfCharacters {
            characters.append(character)
            setupImage()
        }
    }

    open func removeLastCharacter() {
        if characters.count > 0 {
            characters.removeLast()
            setupImage()
        }
    }

    open func allCharacters() -> [Character] {
        return characters
    }

    private func setupImage() {
        for (symbolIndex, symbolImage) in symbolImages.enumerated() {
            symbolImage.image = symbolIndex < characters.count ? R.image.pin.pinFilled() : R.image.pin.pinEmpty()
        }
    }

}
