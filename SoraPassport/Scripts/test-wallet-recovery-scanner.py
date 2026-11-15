#!/usr/bin/env python3
"""Run the production Swift SQLite scanner against synthetic failure fixtures.

No simulator, application database, or wallet keys are used. The enum is
extracted from the current source, so this checks the implementation that ships.
"""
import pathlib
import sqlite3
import subprocess
import tempfile


SOURCE = pathlib.Path(__file__).resolve().parents[1] / "Common/Migration/WalletRecoveryOptions.swift"

ENTRYPOINT = r'''
final class FailingCompanionCopy: FileManager, @unchecked Sendable {
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if srcURL.path.hasSuffix("-wal") { throw CocoaError(.fileReadNoPermission) }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}
let manager: FileManager = CommandLine.arguments.contains("--fail-wal-copy")
    ? FailingCompanionCopy() : .default
switch WalletStoreAccountScan.read(storeURL: URL(fileURLWithPath: CommandLine.arguments[1]), fileManager: manager) {
case .missing: print("missing")
case .inaccessible: print("inaccessible")
case .incomplete: print("incomplete")
case .unreadable: print("unreadable")
case .rows(let rows): print("rows(\(rows.count))")
}
'''


def main():
    source = SOURCE.read_text()
    start = source.index("enum WalletStoreAccountScan {")
    end = source.index("// MARK: - Automatic repair at startup", start)
    with tempfile.TemporaryDirectory(prefix="sora-scanner-regression-") as temporary:
        root = pathlib.Path(temporary)
        harness = root / "Scanner.swift"
        harness.write_text("import Foundation\nimport Darwin\nimport SQLite3\n" + source[start:end] + ENTRYPOINT)
        binary = root / "scanner"
        subprocess.run(["xcrun", "swiftc", str(harness), "-o", str(binary)], check=True, timeout=60)
        checks = 0

        def expect(path, expected, *arguments):
            nonlocal checks
            actual = subprocess.check_output([str(binary), str(path), *arguments], text=True, timeout=20).strip()
            assert actual == expected, f"{path.name}: expected {expected}, got {actual}"
            checks += 1

        def database(name, identifiers):
            path = root / name
            with sqlite3.connect(path) as connection:
                connection.execute("CREATE TABLE ZCDACCOUNTITEM (ZIDENTIFIER TEXT)")
                connection.executemany("INSERT INTO ZCDACCOUNTITEM VALUES (?)", [(item,) for item in identifiers])
            return path

        expect(root / "absent.sqlite", "missing")
        expect(database("empty.sqlite", []), "rows(0)")
        expect(database("full.sqlite", [f"wallet-{i}" for i in range(20)]), "rows(20)")
        expect(database("at-limit.sqlite", [f"wallet-{i}" for i in range(4096)]), "rows(4096)")
        expect(database("over-limit.sqlite", [f"wallet-{i}" for i in range(4097)]), "incomplete")
        expect(database("duplicate.sqlite", ["wallet-a", "wallet-a"]), "rows(1)")
        expect(database("duplicate-over-limit.sqlite", ["wallet-a"] * 4097), "incomplete")
        expect(database("null.sqlite", ["wallet-a", None]), "incomplete")
        expect(database("blank.sqlite", ["wallet-a", ""]), "incomplete")

        damaged = root / "damaged.sqlite"
        connection = sqlite3.connect(damaged)
        connection.execute("PRAGMA page_size=512")
        connection.execute("CREATE TABLE ZCDACCOUNTITEM (ZIDENTIFIER TEXT, ZUSERNAME TEXT)")
        connection.executemany("INSERT INTO ZCDACCOUNTITEM VALUES (?, ?)",
                               [(f"wallet-{i:02d}-" + "a" * 35, "fixture" * 8) for i in range(20)])
        connection.commit()
        pages = connection.execute("SELECT pageno FROM dbstat WHERE name='ZCDACCOUNTITEM' "
                                   "AND pagetype='leaf' ORDER BY pageno").fetchall()
        connection.close()
        assert len(pages) > 1
        contents = bytearray(damaged.read_bytes())
        contents[(pages[-1][0] - 1) * 512] = 0
        damaged.write_bytes(contents)
        expect(damaged, "incomplete")
        assert damaged.read_bytes() == contents, "Scanner changed the source database"

        wal = root / "wal.sqlite"
        connection = sqlite3.connect(wal)
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA wal_autocheckpoint=0")
        connection.execute("CREATE TABLE ZCDACCOUNTITEM (ZIDENTIFIER TEXT)")
        connection.execute("INSERT INTO ZCDACCOUNTITEM VALUES ('checkpointed-wallet')")
        connection.commit()
        connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        connection.execute("INSERT INTO ZCDACCOUNTITEM VALUES ('committed-wal-wallet')")
        connection.commit()
        before = {path: path.read_bytes() for path in (wal, pathlib.Path(str(wal) + "-wal"))}
        expect(wal, "rows(2)")
        expect(wal, "inaccessible", "--fail-wal-copy")
        assert all(path.read_bytes() == data for path, data in before.items()), "Scanner changed original WAL data"
        connection.close()

        for suffix in ("-wal", "-journal", "-shm"):
            path = database(f"nonregular{suffix}.sqlite", ["wallet-a"])
            pathlib.Path(str(path) + suffix).mkdir()
            expect(path, "inaccessible")
        print(f"PASS: {checks} production scanner regression checks; original database and WAL preserved")


if __name__ == "__main__":
    main()
