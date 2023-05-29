import UIKit
import SoraUIKit

private final class WordColumnView: SoramitsuView {
    private var indexes: [SoramitsuLabel] = []
    private var words: [SoramitsuLabel] = []

    var horizontalSpacing: CGFloat = 16.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 2.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var indexTitleColor: SoramitsuColor = .fgPrimary {
        didSet {
            applyIndexStyle(to: indexes)
        }
    }

    var indexFont: FontData = FontType.textL {
        didSet {
            applyIndexStyle(to: indexes)

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var wordTitleColor: SoramitsuColor = .fgPrimary {
        didSet {
            applyWordStyle(to: words)
        }
    }

    var wordFont: FontData = FontType.textBoldL {
        didSet {
            applyWordStyle(to: words)

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    override var intrinsicContentSize: CGSize {
        let indexSize = indexes.reduce(CGSize(width: 0.0, height: 0.0)) { (result, indexLabel) in
            let indexSize = indexLabel.intrinsicContentSize
            return CGSize(width: max(result.width, indexSize.width),
                          height: result.height + indexSize.height)
        }

        let wordsSize = words.reduce(CGSize(width: 0.0, height: 0.0)) { (result, wordLabel) in
            let wordSize = wordLabel.intrinsicContentSize
            return CGSize(width: max(result.width, wordSize.width),
                          height: result.height + wordSize.height)
        }

        return CGSize(width: indexSize.width + horizontalSpacing + wordsSize.width,
                      height: max(indexSize.height, wordsSize.height) + CGFloat(words.count - 1) * verticalSpacing)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let maxIndexWidth: CGFloat = indexes.reduce(CGFloat(0.0)) { (result, label) in
            max(result, label.intrinsicContentSize.width)
        }

        var currentOffset: CGFloat = 0.0

        for (index, wordLabel) in words.enumerated() {
            let indexLabel = indexes[index]
            let wordSize = wordLabel.intrinsicContentSize
            let indexSize = indexLabel.intrinsicContentSize

            let height = max(wordSize.height, indexSize.height)

            indexLabel.frame = CGRect(x: 0.0,
                                      y: currentOffset + height / 2.0 - indexSize.height / 2.0,
                                      width: indexSize.width,
                                      height: indexSize.height)

            wordLabel.frame = CGRect(x: maxIndexWidth + horizontalSpacing,
                                     y: currentOffset + height / 2.0 - wordSize.height / 2.0,
                                     width: wordSize.width,
                                     height: wordSize.height)

            currentOffset += height + verticalSpacing
        }
    }

    func bind(words: [String], starting index: Int) {
        setupColumn(count: words.count)

        for (wordIndex, word) in words.enumerated() {
            if word != "" {
                self.words[wordIndex].sora.text = word
                self.indexes[wordIndex].sora.text = String(index + wordIndex)
            }
        }

        invalidateIntrinsicContentSize()

        setNeedsLayout()
    }

    // MARK: Private

    func setupColumn(count: Int) {
        if words.count < count {
            let newIndexes: [SoramitsuLabel] = (0..<(count - words.count)).map { _ in SoramitsuLabel() }
            let newWords: [SoramitsuLabel] = (0..<(count - words.count)).map { _ in SoramitsuLabel() }

            applyIndexStyle(to: newIndexes)
            applyWordStyle(to: newWords)

            newIndexes.forEach { addSubview($0) }
            newWords.forEach { addSubview($0) }

            indexes.append(contentsOf: newIndexes)
            words.append(contentsOf: newWords)
        } else if words.count > count {
            let removedIndexes = indexes.dropLast(words.count - count)
            let removedWords = words.dropLast(words.count - count)

            removedIndexes.forEach { $0.removeFromSuperview() }
            removedWords.forEach { $0.removeFromSuperview() }
        }
    }

    func applyIndexStyle(to list: [SoramitsuLabel]) {
        list.forEach { label in
            label.sora.font = indexFont
            label.sora.textColor = indexTitleColor
        }
    }

    func applyWordStyle(to list: [SoramitsuLabel]) {
        list.forEach { label in
            label.sora.textColor = wordTitleColor
            label.sora.font = wordFont
        }
    }
}

final class MnemonicDisplayView: SoramitsuView {
    var columnsSpacing: CGFloat = 80.0 {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var horizontalSpacingInColumn: CGFloat {
        get {
            mainColumn.horizontalSpacing
        }

        set {
            mainColumn.horizontalSpacing = newValue

            otherColumns.forEach { $0.horizontalSpacing = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var verticalSpacingInColumn: CGFloat {
        get {
            mainColumn.verticalSpacing
        }

        set {
            allColumns.forEach { $0.verticalSpacing = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var indexTitleColorInColumn: SoramitsuColor {
        get {
            mainColumn.indexTitleColor
        }

        set {
            allColumns.forEach { $0.indexTitleColor = newValue }
        }
    }

    var indexFontInColumn: FontData {
        get {
            mainColumn.indexFont
        }

        set {
            allColumns.forEach { $0.indexFont = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var wordTitleColorInColumn: SoramitsuColor {
        get {
            mainColumn.wordTitleColor
        }

        set {
            allColumns.forEach { $0.wordTitleColor = newValue }
        }
    }

    var wordFontInColumn: FontData {
        get {
            mainColumn.wordFont
        }

        set {
            allColumns.forEach { $0.wordFont = newValue }

            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private var mainColumn: WordColumnView = WordColumnView()
    private var otherColumns: [WordColumnView] = []

    private var allColumns: [WordColumnView] {
        return [mainColumn] + otherColumns
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    override var intrinsicContentSize: CGSize {
        let columnsSize = allColumns.reduce(CGSize.zero) { (result, column) in
            let columnSize = column.intrinsicContentSize

            return CGSize(width: result.width + columnSize.width,
                          height: max(columnSize.height, result.height))
        }

        return CGSize(width: columnsSize.width + CGFloat(allColumns.count - 1) * columnsSpacing,
                      height: columnsSize.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let totalSize = intrinsicContentSize

        var offset: CGFloat = bounds.size.width / 2.0 - totalSize.width / 2.0

        for column in allColumns {
            let columnSize = column.intrinsicContentSize
            column.frame = CGRect(x: offset,
                                  y: 0,
                                  width: columnSize.width,
                                  height: columnSize.height)
            offset += columnSize.width + columnsSpacing
        }
    }

    func bind(words: [String], columnsCount: Int) {
        guard columnsCount > 0, words.count % columnsCount == 0 else {
            return
        }

        let wordsPerColumn = words.count / columnsCount

        setupColumns(count: columnsCount)

        for columnIndex in (0..<columnsCount) {
            let start = columnIndex * wordsPerColumn
            let end = (columnIndex + 1) * wordsPerColumn

            allColumns[columnIndex].bind(words: Array(words[start..<end]), starting: start + 1)
        }
    }

    // MARK: Private

    private func configure() {
        backgroundColor = .clear

        addSubview(mainColumn)
    }

    private func setupColumns(count: Int) {
        if allColumns.count < count {
            let newColumnsCount = count - allColumns.count
            let newColumns: [WordColumnView] = (0..<newColumnsCount).map { _ in
                let column = WordColumnView()
                column.horizontalSpacing = mainColumn.horizontalSpacing
                column.verticalSpacing = mainColumn.verticalSpacing
                column.indexTitleColor = mainColumn.indexTitleColor
                column.indexFont = mainColumn.indexFont
                column.wordTitleColor = mainColumn.wordTitleColor
                column.wordFont = mainColumn.wordFont
                return column
            }

            newColumns.forEach { addSubview($0) }

            otherColumns.append(contentsOf: newColumns)
        } else if allColumns.count > count {
            let removedColumns = otherColumns.dropLast(allColumns.count - count)
            removedColumns.forEach { $0.removeFromSuperview() }
        }
    }
}
