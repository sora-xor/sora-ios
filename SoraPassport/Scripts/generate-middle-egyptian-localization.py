#!/usr/bin/env python3
"""Generate and verify the linear hieroglyphic Middle Egyptian localization.

The English catalog remains the key/format-token authority.  This generator
uses a deliberately small, reviewed Middle Egyptian semantic vocabulary.  Long
modern prose is compressed into Egyptian clause-sized sense groups rather than
being disguised English syntax.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]
SOURCE = APP_ROOT / "SoraLocalizable/en.lproj/Localizable.strings"
TARGET = APP_ROOT / "SoraLocalizable/egy.lproj/Localizable.strings"
FALLBACK_SECTION = "/* Wallet and connected-app UX: English fallback for untranslated locales. */"
FONT = APP_ROOT / "Fonts/NotoSansEgyptianHieroglyphs-Regular.ttf"
FONT_LICENSE = APP_ROOT / "Fonts/NotoSansEgyptianHieroglyphs-OFL.txt"
FONT_SHA256 = "38a33a230624671eebedce95bd4237f7b3b2bb1fa25688ff959bed4070a1ea95"
FONT_LICENSE_SHA256 = "dc8114a49f5bb53bad3d99ee52cbb245e98076438d59428a258720258494de68"

SIGN_NAMES = {
    "ꜣ": "G001", "j": "M017", "y": "M017", "ꜥ": "D036",
    "w": "G043", "b": "D058", "p": "Q003", "f": "I009",
    "m": "G017", "n": "N035", "r": "D021", "h": "O004",
    "ḥ": "V028", "ḫ": "AA001", "ẖ": "F032", "z": "O034",
    "s": "S029", "š": "N037", "q": "N029", "ḳ": "N029", "k": "V031",
    "g": "W011", "t": "X001", "ṯ": "V013", "d": "D046",
    "ḏ": "I010",
}
SIGNS = {
    letter: unicodedata.lookup(f"EGYPTIAN HIEROGLYPH {name}")
    for letter, name in SIGN_NAMES.items()
}

# Identifiers remain literal because changing them can make wallet operations
# ambiguous.  They are protected before transliteration is converted to signs.
LITERALS = {
    "SORA", "Sora", "Polkaswap", "Polkamarkt", "XOR", "VAL", "ETH",
    "ADAR", "KUSD", "QR", "PIN", "IBAN", "JSON", "URL", "SMS", "APR",
    "APY", "LP", "DeFi", "AMM", "DEX", "TBC", "XYK", "XST", "ERC20",
    "Substrate", "Polkadot", "Kusama", "Ethereum", "Google", "GitHub",
    "Google Drive", "Demeter", "ATM", "polkaswap",
    "Telegram", "Twitter", "YouTube", "Instagram", "Medium", "Wiki",
    "Touch ID", "Face ID", "App Store", "SORA NET", "SORA Card", "EUR",
    "x*y=k", "@SORAhappiness", "hex",
}

# Attested roots and transparent compounds.  Values are Egyptological
# transliterations; encode_hieroglyphs turns them into Unicode signs.
WORDS = {
    # grammar and relations
    "and": "ḥnꜥ", "or": "r-pw", "not": "n", "no": "nn", "without": "nn",
    "in": "m", "into": "r ẖnw", "inside": "m ẖnw", "on": "ḥr", "under": "ẖr",
    "from": "m", "to": "r", "for": "n", "of": "n", "with": "ḥnꜥ",
    "before": "m-bꜣḥ", "after": "m-ḫt", "between": "m-m", "through": "m",
    "by": "m", "as": "mj", "if": "jr", "then": "wnn", "this": "pn",
    "these": "nn", "that": "pw", "every": "nb", "all": "nb", "any": "nb",
    "another": "ky", "other": "ky", "same": "wꜥ", "one": "wꜥ", "many": "ꜥšꜣ",
    "some": "nhy", "more": "ꜥšꜣ", "only": "wꜥ", "first": "tpj", "last": "pḥwj",
    "new": "mꜣw", "current": "ntt", "now": "mjn", "later": "m-ḫt",
    "soon": "m-ḫt nḏs", "again": "m wḥm", "here": "m st tn", "there": "m st pf",
    "yes": "jw", "ok": "nfr", "please": "m ḥtp", "very": "wrt",
    "too": "wrt", "at": "m", "per": "n", "left": "wꜣḥ", "out": "r rwty",
    "up": "ḥr", "down": "ẖr", "back": "m-ḫt", "away": "r rwty",
    "i": "jnk", "we": "jn", "you": "tw", "your": "n.k", "my": "n.j",
    "our": "n.n", "their": "n.sn", "them": "sn", "they": "sn", "it": "st",
    "is": "wn", "are": "wn", "be": "wn", "been": "wn", "was": "wn",
    "were": "wn", "will": "r", "would": "r", "may": "r", "can": "rḫ",
    "cannot": "n rḫ", "can't": "n rḫ", "must": "ḥtr", "should": "ḥtr",
    "have": "wn", "has": "wn", "had": "wn", "do": "jr", "does": "jr",
    "did": "jr", "than": "r", "when": "tr", "where": "st", "how": "mj jḫ",
    "who": "mj", "which": "jḫ", "what": "jḫ", "because": "ntt",

    # wallet concepts
    "wallet": "pr ḥḏ", "account": "ḥsb", "accounts": "ḥsbw",
    "network": "jꜣdt nt wꜣwt", "networks": "jꜣdt nt wꜣwt",
    "node": "sbꜣ n jꜣdt", "nodes": "sbꜣw n jꜣdt",
    "transaction": "jrt swnt", "transactions": "jrwt swnt",
    "hash": "ḫtm", "block": "ḏbt", "blockchain": "ṯs n ḏbwt",
    "blockchains": "ṯs n ḏbwt", "backup": "šꜥt snnw", "password": "mdw n wn",
    "passwords": "mdw n wn", "passphrase": "ṯs mdw", "passphrases": "ṯs mdw",
    "mnemonic": "ṯs mdw", "seed": "prt štꜣ", "raw": "štꜣ",
    "asset": "jḫt", "assets": "jḫt", "token": "jḫt", "tokens": "jḫt",
    "fund": "jḫt", "funds": "jḫt", "balance": "jḫt ntt",
    "balances": "jḫt ntt", "price": "jsw", "prices": "jsw", "fee": "bꜣkw",
    "fees": "bꜣkw", "liquidity": "mw ḥḏ", "pool": "š n mw", "pools": "šw n mw",
    "farm": "ꜣḥt", "farms": "ꜣḥwt", "farming": "jrt m ꜣḥt",
    "staking": "ṯs jḫt", "stake": "ṯs jḫt", "staked": "ṯs jḫt",
    "unstake": "wḫꜣ ṯs", "unstaked": "wḫꜣ ṯs", "bond": "ṯs",
    "bonded": "ṯs", "unbond": "wḫꜣ ṯs", "unbonded": "wḫꜣ ṯs",
    "unbonding": "ḥr wḫꜣ ṯs", "swap": "dbꜣ", "swapped": "dbꜣ",
    "trade": "swn", "trading": "swn", "market": "st swn", "markets": "stwt swn",
    "currency": "ḥḏ", "currencies": "ḥḏw", "crypto": "ḫtm štꜣ",
    "fiat": "ḥḏ n tꜣ", "cash": "ḥḏ", "collateral": "jḫt rdj",
    "share": "psš", "shares": "psšw", "pooled": "m š n mw",
    "allocation": "psš", "slippage": "snj jsw", "route": "wꜣt",
    "provider": "rdj", "providers": "rdjw", "miner": "bꜣk", "curve": "pḏt",
    "portfolio": "dmḏt jḫt", "card": "šꜥt", "exchange": "dbꜣ",
    "payment": "rḏjt ḥḏ", "amount": "ḥsb", "total": "dmḏ",
    "minimum": "nḏs", "min": "nḏs", "maximum": "ꜥꜣ", "max": "ꜥꜣ",
    "insufficient": "n ḳm", "redeemable": "šsp rḫ", "reserved": "sꜣw",
    "locked": "ḫtm", "frozen": "ḫtm", "transferable": "hꜣb rḫ",
    "transferrable": "hꜣb rḫ", "withdrawal": "jnj r rwty",
    "withdraw": "jnj r rwty", "withdrawn": "jnj r rwty", "deposit": "rdj m ẖnw",

    # actions and states
    "use": "jr", "using": "jr", "open": "wn", "close": "ḫtm", "closed": "ḫtm",
    "save": "sꜣw", "protect": "sꜣw", "protection": "sꜣw", "secure": "sꜣw",
    "security": "sꜣw", "cancel": "wꜣḥ", "skip": "swꜣ", "continue": "šm",
    "next": "m-ḫt", "retry": "jr m wḥm", "try": "jr", "apply": "jr",
    "applied": "jr", "create": "ḳmꜣ", "created": "ḳmꜣ", "make": "jr",
    "made": "jr", "add": "dmḏ", "added": "dmḏ", "remove": "dr",
    "removed": "dr", "delete": "dr", "deleting": "dr", "forget": "mhj",
    "edit": "snj", "change": "snj", "changed": "snj", "changes": "snjw",
    "update": "smꜣw", "updated": "smꜣw", "refresh": "smꜣw", "rewrite": "sš m wḥm",
    "select": "stp", "choose": "stp", "choosing": "stp", "show": "mꜣꜣ",
    "view": "mꜣꜣ", "see": "mꜣꜣ", "hide": "jmn", "search": "ḥḥj",
    "scan": "ptr ḫtm", "copy": "sš m wḥm", "copied": "sš m wḥm",
    "write": "sš", "written": "sš", "read": "šdj", "download": "jnj m pt",
    "upload": "hꜣb r pt", "export": "hꜣb r rwty", "import": "jnj r ẖnw",
    "imported": "jnj r ẖnw", "send": "hꜣb", "sending": "hꜣb",
    "sent": "hꜣb", "receive": "šsp", "received": "šsp", "claim": "šsp",
    "claimed": "šsp", "buy": "jnj m jsw", "buying": "jnj m jsw",
    "sell": "rdj m jsw", "supply": "rdj", "supplied": "rdj",
    "provide": "rdj", "provided": "rdj", "join": "dmḏ", "joined": "dmḏ",
    "connect": "dmḏ", "connected": "dmḏ", "connecting": "ḥr dmḏ",
    "switch": "snj", "run": "šm", "start": "šsp tp", "ended": "pḥwy",
    "completed": "km", "complete": "km", "done": "km", "pending": "m ꜣwt",
    "progress": "ḥr ḫpr", "active": "ꜥnḫ", "enabled": "wn", "disabled": "ḫsf",
    "available": "wn", "unavailable": "nn wn", "failed": "n mnḫ",
    "fail": "n mnḫ", "successful": "mnḫ", "successfully": "m mnḫ",
    "success": "mnḫ", "wrong": "n mꜣꜥ", "invalid": "n mꜣꜥ",
    "incorrect": "n mꜣꜥ", "correct": "mꜣꜥ", "unknown": "n rḫ",
    "verify": "smn", "verified": "smn", "verifying": "ḥr smn",
    "verification": "smn", "confirm": "smn", "confirmation": "smn",
    "authenticate": "smn rn", "authentication": "smn rn", "authorization": "smn rn",
    "authorized": "smn rn", "sign": "ḫtm", "signing": "ḫtm",
    "revert": "jr m wḥm", "rejected": "ḫsf", "accept": "šsp",
    "accepted": "šsp", "allow": "rḏj", "denied": "ḫsf", "enable": "rḏj wn",
    "freeze": "ḫtm", "top": "mḥ", "pay": "rḏj ḥḏ", "earn": "šsp ḥzwt",
    "recover": "sꜥnḫ", "recovering": "ḥr sꜥnḫ", "restore": "sꜥnḫ",
    "load": "jnj", "loading": "ḥr jnj", "install": "rdj m ẖnw",
    "installed": "rdj m ẖnw", "reinstall": "rdj m ẖnw m wḥm",
    "restart": "šsp tp m wḥm", "submit": "hꜣb", "submitted": "hꜣb",
    "review": "ptr", "discover": "gmj", "explore": "ḥḥj", "expand": "sꜣꜣ",
    "collapse": "sꜣw nḏs", "manage": "ḫrp", "set": "smn", "setting": "smnt",
    "setup": "smn", "hold": "sꜣw", "nominate": "stp", "nominating": "stp",

    # people, records, and UI nouns
    "name": "rn", "identifier": "rn", "id": "rn", "address": "st",
    "addresses": "stwt", "user": "rmṯ", "users": "rmṯw", "person": "rmṯ",
    "recipient": "šsp", "recipients": "šspw", "sender": "hꜣb", "friend": "ḫnms",
    "friends": "ḫnmsw", "referrer": "njs", "referrer's": "n njs",
    "referrer’s": "n njs", "referral": "njs", "referrals": "njsw",
    "invitation": "njs", "invitations": "njsw", "invite": "njs",
    "code": "ḫtm", "key": "ꜥ n wn", "proof": "ḫtm mꜣꜥ",
    "phone": "mḏꜣt nt ꜥ", "mobile": "mḏꜣt nt ꜥ", "device": "mḏꜣt nt ꜥ",
    "application": "mḏꜣt", "applications": "mḏꜣwt", "app": "mḏꜣt",
    "software": "mdw jrt", "version": "ḳd", "settings": "smnt",
    "appearance": "ḳd", "mode": "ḳd", "dark": "kkw", "language": "mdw",
    "information": "rḫt", "info": "rḫt", "details": "rḫt nb", "data": "rḫt sš",
    "source": "tp", "history": "sšw n ḫt", "activity": "jrwt",
    "status": "ḳd", "result": "prj", "results": "prjw", "response": "wšb",
    "request": "dbḥ", "requests": "dbḥw", "query": "dbḥ", "question": "dbḥ",
    "questions": "dbḥw", "concerns": "jbw", "notification": "smj",
    "notifications": "smjw", "announcement": "smj", "announcements": "smjw",
    "message": "wpwty", "note": "sš", "word": "mdw", "words": "mdw",
    "symbol": "zš", "symbols": "zšw", "characters": "zšw", "letters": "zšw",
    "number": "ḥsb", "numbers": "ḥsbw", "digit": "ḥsb", "format": "ḳd",
    "file": "šꜥt", "document": "šꜥt", "documents": "šꜥwt", "paper": "šꜥt",
    "link": "ṯs wꜣt", "browser": "ptr wꜣt", "website": "pr n wꜣt",
    "email": "šꜥt nt pt", "mail": "šꜥt nt pt", "gallery": "pr zšw",
    "library": "pr zšw", "clipboard": "mḏꜣt nt ꜥ", "screen": "ptr",
    "screenshots": "zšw n ptr", "project": "kꜣt", "projects": "kꜣwt",
    "vote": "rḏj ḫrw", "votes": "ḫrw", "voted": "rdj ḫrw", "voting": "rḏj ḫrw",
    "rank": "st", "reputation": "rn nfr", "profile": "rn rmṯ", "personal": "n ds",
    "privacy": "sꜣw štꜣ", "policy": "hp", "terms": "hpw", "conditions": "hpw",
    "legal": "hpw", "law": "hp", "laws": "hpw", "disclaimer": "sš n sꜣw",
    "support": "nḏ-ḥr", "help": "nḏ-ḥr", "faq": "dbḥw ḥnꜥ wšbw",
    "contact": "dmḏ", "contacts": "rḫw", "community": "dmḏt rmṯw",
    "world": "tꜣ", "worlds": "tꜣw", "economy": "pr ḥḏ n tꜣ",
    "governance": "ḫrp", "parliament": "dmḏt n mdw", "service": "bꜣk",
    "services": "bꜣkw", "feature": "jrt", "option": "stp", "options": "stpw",
    "action": "jrt", "operation": "jrt", "type": "ḳd", "title": "rn",
    "tab": "st", "list": "sšw", "button": "ꜥ n jrt", "label": "rn",
    "warning": "sꜣw", "attention": "rdj jb", "error": "btꜣ", "problem": "btꜣ",
    "issue": "btꜣ", "risk": "ḫt bjn", "risks": "ḫt bjn", "malware": "ḫt bjn",

    # descriptive vocabulary used by longer notices
    "enough": "ḳm", "important": "ꜥꜣ", "public": "n rmṯw nb", "internal": "m ẖnw",
    "external": "m rwty", "long": "ꜣw", "longer": "ꜣw", "short": "nḏs",
    "small": "nḏs", "large": "ꜥꜣ", "best": "nfr wrt", "free": "nn bꜣk",
    "full": "mḥ", "visible": "mꜣꜣ", "hidden": "jmn", "local": "n st tn",
    "locally": "m st tn", "official": "smn", "custom": "n.k ds.k",
    "default": "tpj", "optional": "stp rḫ", "mandatory": "ḥtr", "secret": "štꜣ",
    "private": "štꜣ", "digital": "n mḏꜣt", "biometric": "ḫtm ẖt",
    "decentralized": "nn nb wꜥ", "economic": "n pr ḥḏ", "annual": "n rnpt",
    "annualized": "n rnpt", "daily": "m hrw nb", "recent": "mꜣw",
    "online": "ḥr jꜣdt nt wꜣwt", "offline": "nn wꜣt", "stable": "mn",
    "exact": "mꜣꜥ", "estimated": "m ḥsb", "synthetic": "ḳmꜣ",
    "traditional": "mj tp-ꜥ", "primary": "tpj", "secondary": "snnw",
    "different": "ky", "compatible": "dmḏ rḫ", "associated": "dmḏ",
    "matching": "mj", "supported": "sꜣw", "improved": "sꜣꜣ nfr",
    "highly": "wrt", "weak": "nḏs", "ready": "smn", "positive": "nfr",
    "unexpected": "nn m ḫmt", "unexpectedly": "nn m ḫmt", "ambiguous": "ḥr 2",
    "duplicate": "m wḥm", "duplicated": "m wḥm", "missing": "nn wn",
    "available": "wn", "properly": "m mꜣꜥ", "temporarily": "n tr nḏs",
    "forever": "r nḥḥ", "safely": "m sꜣw", "securely": "m sꜣw",
    "voluntary": "m jb", "sole": "wꜥ", "particular": "pn", "alpha": "tp-ꜥ",
    "fully": "mḥ", "latest": "mꜣw", "extra": "ḥr ḫt", "additional": "ḥr ḫt",
    "zero": "nn", "wrongly": "n mꜣꜥ", "unfavorable": "bjn", "unfavorably": "m bjn",
    "favorable": "nfr", "proportional": "m ḥsb", "combined": "dmḏ",
    "guaranteed": "smn", "interoperable": "dmḏ rḫ", "non": "nn",
    "custodial": "sꜣw", "trusted": "mꜣꜥ", "faster": "ꜣw",
    "worth": "jsw", "liquid": "mw ḥḏ", "excluded": "dr", "certain": "smn",
    "six": "6", "uppercase": "zšw ꜥꜣw", "alphabetic": "zšw n rn",
    "alphanumeric": "zšw ḥnꜥ ḥsbw", "hex": "hex", "size": "ḥsb",
    "length": "ꜣwt", "rate": "jsw", "ratio": "ḥsb m-m", "percentage": "psš m 100",
    "point": "ḥsb", "points": "ḥsbw", "portion": "psš", "pair": "2",
    "day": "hrw", "date": "hrw", "time": "tr", "today": "hrw pn",
    "yesterday": "sf", "moment": "ꜣt", "hour": "wnwt", "seconds": "ꜣt nḏst",
    "sec": "ꜣt nḏst", "year": "rnpt", "country": "tꜣ", "countries": "tꜣw",
    "world": "tꜣ", "worlds": "tꜣw", "euro": "EUR", "cash": "ḥḏ",
    "reward": "ḥzwt", "rewards": "ḥzwt", "payout": "rḏjt ḥzwt",
    "distribution": "psš", "growth": "sꜣꜣ", "return": "šsp", "investment": "rdj jḫt",
    "incentive": "ḥzwt", "goods": "jḫt nfr", "creation": "ḳmꜣt",
    "funding": "rḏjt ḥḏ", "producer": "jrj", "producers": "jrjw",
    "proposal": "mdw", "proposals": "mdw", "supervision": "mꜣꜣ",
    "experience": "rḫt", "responsibility": "jrt n ds", "reponsibility": "jrt n ds",
    "compliance": "jr hpw", "jurisdiction": "tꜣ n hpw", "memorandum": "šꜥt",
    "documentation": "šꜥwt", "explanation": "sḏd", "understanding": "rḫ",
    "consent": "jb", "opportunity": "wꜣt", "intermediaries": "rmṯw m-m",
    "ecosystem": "dmḏt", "source": "tp", "sources": "tpw", "algorithm": "hp n ḥsb",
    "position": "st", "maker’s": "n jrj", "taker": "šsp", "trader": "swnw",
    "creator": "ḳmꜣ", "probability": "ḥsb n ḫpr", "tolerance": "wꜣḥ jb",
    "movement": "šm", "frontrun": "swꜣ m-bꜣḥ", "routing": "stp wꜣt",
    "recovery": "sꜥnḫ", "phrase": "ṯs mdw", "identity": "rn mꜣꜥ",
    "credentials": "ḫtmw n wn", "archive": "pr sšw", "allocation": "psš",
    "provider": "rdj", "provision": "rḏjt", "holder": "nb", "holders": "nbw",
}

# Less frequent source-language forms.  Keeping these separate makes the core
# semantic glossary above readable while ensuring that no English prose leaks
# into the generated locale.
WORDS.update({
    "enter": "rdj m ẖnw", "but": "js", "access": "wn", "already": "m-bꜣḥ",
    "sorry": "ḥtp jb.k", "n": "n", "need": "ḥtr", "required": "ḥtr",
    "requires": "ḥtr", "requirement": "ḥtr", "transition": "šm",
    "transfer": "hꜣb", "get": "šsp", "getting": "šsp", "v": "ḳd",
    "working": "ḥr jr", "work": "jr", "works": "jr", "don't": "m",
    "don’t": "m", "about": "r", "order": "ṯs", "system": "dmḏt",
    "registration": "rḏj rn", "registered": "rḏj rn", "yet": "mjn",
    "least": "nḏs", "check": "mꜣꜣ", "below": "ẖr", "above": "ḥr",
    "output": "prj", "input": "rdj m ẖnw", "go": "šm", "goes": "šm",
    "want": "mr", "connection": "dmḏ", "favourite": "mry",
    "favourites": "mryw", "favs": "mryw", "whenever": "tr nb",
    "proceed": "šm", "able": "rḫ", "unable": "n rḫ", "validator": "smn",
    "validators": "smnw", "idator": "smn", "protocol": "hp n jrt",
    "bridge": "dꜣjt", "chain": "ṯs", "become": "ḫpr", "still": "wꜣḥ",
    "welcome": "jjj m ḥtp", "smart": "sꜣꜣ", "well": "nfr",
    "swipe": "sḫn ꜥ", "agreeing": "šsp", "step": "st", "once": "sp wꜥ",
    "hard": "m pḥty", "fix": "smn", "you've": "wn n.k", "you’ll": "r n.k",
    "wouldn’t": "n r", "wouldn't": "n r", "couldn’t": "n rḫ", "couldn't": "n rḫ", "wasn't": "n wn",
    "isn't": "n wn", "it's": "st pw", "spent": "rdj", "tap": "sḫn ꜥ",
    "congratulations": "ḥtp n.k", "yourself": "ds.k", "parameters": "hpw",
    "wait": "ꜣwt", "waiting": "ḥr ꜣwt", "like": "mj", "includes": "ẖnm",
    "include": "ẖnm", "including": "ẖnm", "used": "jr", "future": "m-ḫt",
    "based": "mn ḥr", "via": "m", "auth": "smn rn", "appear": "ḫꜥ",
    "currently": "mjn", "none": "nn", "financing": "rḏjt ḥḏ",
    "exciting": "nfr", "democratic": "n rmṯw nb", "so": "nn",
    "process": "jrt", "affected": "snj", "stored": "sꜣw", "store": "sꜣw",
    "also": "grt", "given": "rdj", "acknowledge": "rḫ", "understand": "rḫ",
    "learn": "rḫ", "activate": "sꜥnḫ", "follow": "šm m-ḫt", "me": "wj",
    "paid": "rdj ḥḏ", "desired": "mrr", "validate": "smn", "exists": "wn",
    "ticker": "rn n jḫt", "match": "mj", "matched": "mj", "demeter": "Demeter",
    "chat": "mdw ḥnꜥ", "refer": "njs", "space": "st", "resource": "jḫt",
    "further": "ḥr ḫt", "steps": "stwt", "handling": "ḫrp", "repeat": "jr m wḥm",
    "scratch": "tp-ꜥ", "discuss": "mdw", "restrict": "sꜣw", "unauthorized": "nn smn rn",
    "accessing": "wn", "contains": "ẖnm", "contain": "ẖnm", "determine": "rḫ",
    "displayed": "ḫꜥ", "display": "ḫꜥ", "anymore": "m-ḫt", "interpreted": "rḫ",
    "configured": "smn", "user's": "n rmṯ", "values": "jsw", "value": "jsw",
    "increased": "sꜣꜣ", "reached": "pḥ", "deadline": "tr pḥwj",
    "frequent": "sp ꜥšꜣ", "expired": "pḥ tr", "improvements": "sꜣꜣ nfr",
    "bug": "btꜣ", "fixes": "smn", "during": "m tr", "arrive": "jjj",
    "unsuccessful": "n mnḫ", "e": "šꜥt nt pt", "most": "wr", "succeeds": "mnḫ",
    "everybody": "rmṯw nb", "gets": "šsp", "deciding": "wḏ", "got": "šsp",
    "just": "mꜣꜥ", "manually": "m ꜥ", "resend": "hꜣb m wḥm",
    "taken": "šsp", "take": "šsp", "leave": "wꜣḥ", "advanced": "sꜣꜣ",
    "associating": "ḥr dmḏ", "swapping": "dbꜣ", "parachains": "wꜣwt ḏbwt",
    "effectively": "m mnḫ", "logout": "prj r rwty", "launched": "šsp tp",
    "someone": "rmṯ", "operate": "jr", "shown": "ḫꜥ", "belongs": "n",
    "right": "mꜣꜥ", "limitations": "drw", "means": "mdw", "incoming": "jjj",
    "apologize": "ḥtp jb.k", "inconvenience": "ḫt bjn", "caused": "jr",
    "resolve": "smn", "sold": "rdj m jsw", "maintained": "sꜣw",
    "detailed": "mḥ", "crucial": "ꜥꜣ", "multiverse": "tꜣw ꜥšꜣ",
    "mentioned": "ḏd", "following": "m-ḫt", "built": "ḳd", "natively": "m ḳd ds",
    "thank": "dwꜣ", "part": "psš", "decentralize": "dr nb wꜥ",
    "nominators": "stpw", "wish": "mr", "subscribe": "dmḏ", "ask": "dbḥ",
    "ensures": "smn", "combining": "dmḏ", "affordable": "jsw nḏs", "upon": "ḥr",
    "utilized": "jr", "possibility": "rḫ ḫpr", "compared": "mꜣꜣ m-m",
    "vested": "sꜣw", "might": "r", "turn": "snj", "much": "ꜥšꜣ", "maker's": "n jrj",
    "over": "ḥr", "anyone": "rmṯ nb", "shifting": "snj", "maker’s": "n jrj",
    "dealt": "jr", "tx": "jrt swnt", "converts": "snj", "each": "nb",
    "cover": "sꜣw", "unused": "nn jr", "batch": "dmḏt", "encrypt": "ḫtm štꜣ",
    "established": "smn", "really": "m mꜣꜥ", "reload": "jnj m wḥm",
    "invest": "rdj jḫt", "global": "n tꜣ nb", "amountof": "ḥsb",
    "transacting": "ḥr jrt swnt", "could": "rḫ", "devs": "jrjw mḏꜣt",
    "guess": "ḫmt", "aimed": "ḥr", "ensure": "smn", "atm": "ATM",
    "issuance": "rḏjt", "way": "wꜣt", "receiever": "šsp", "attempts": "spw",
    "such": "mj nn", "residents": "rmṯw n", "alternative": "ky",
    "matched": "mj", "decide": "wḏ", "builds": "ḳd", "succesfully": "m mnḫ",
    "little": "nḏs", "powered": "sḫm m", "decryption": "wn ḫtm štꜣ",
    "fulfilled": "km", "something": "jḫt", "went": "šm", "occured": "ḫpr",
    "troubleshoot": "smn btꜣ", "bonus": "ḥzwt", "standalone": "wꜥ ds",
    "involves": "ẖnm", "both": "2", "drive": "Google Drive", "losing": "ḥtm",
    "unfortunately": "ḥtp jb.k", "previously": "m-bꜣḥ", "possibly": "rḫ ḫpr",
    "entered": "rdj m ẖnw", "denotes": "mdw", "participating": "dmḏ",
    "corresponding": "mj",
    "german": "mdw n grmn", "norwegian": "mdw n nrwg", "turkish": "mdw n trk",
    "hebrew": "mdw n ꜥbr", "persian": "mdw n prs", "serbian": "mdw n srb",
    "vietnamese": "mdw n fjtnm", "hindi": "mdw n hnd",
    "azerbaijani": "mdw n ꜣzrbjḏꜣn", "dutch": "mdw n ndr",
    "portuguese": "mdw n prtgjz",
})

STOP_WORDS = {
    "the", "a", "an", "s", "t", "ll", "ve", "re", "m", "h", "d",
}

PHRASES = {
    "please try again later": "jr m wḥm m-ḫt",
    "try again later": "jr m wḥm m-ḫt",
    "try again": "jr m wḥm",
    "not enough": "n ḳm",
    "is not found": "n gmj",
    "are not found": "n gmj",
    "not found": "n gmj",
    "will appear here": "r ḫꜥ m st tn",
    "will be displayed here": "r ḫꜥ m st tn",
    "in progress": "ḥr ḫpr",
    "are you sure": "jn smn jb.k",
    "do you want to": "jn jr.k",
    "would you like to": "jn jr.k",
    "make sure": "smn",
    "pay attention": "rdj jb",
    "terms and conditions": "hpw",
    "privacy policy": "hp n sꜣw štꜣ",
    "source code": "mdw n ḳmꜣt",
    "raw seed": "prt štꜣ",
    "pin code": "ḫtm PIN",
    "invite code": "ḫtm n njs",
    "invitation code": "ḫtm n njs",
    "verification code": "ḫtm n smn",
    "network fee": "bꜣkw n jꜣdt nt wꜣwt",
    "miner fee": "bꜣkw n bꜣk",
    "account id": "rn n ḥsb",
    "asset id": "rn n jḫt",
    "token price": "jsw n jḫt",
    "pool share": "psš n š n mw",
    "liquidity pool": "š n mw",
    "supply liquidity": "rḏj mw ḥḏ",
    "provide liquidity": "rḏj mw ḥḏ",
    "add liquidity": "dmḏ mw ḥḏ",
    "remove liquidity": "dr mw ḥḏ",
    "insufficient balance": "n ḳm jḫt ntt",
    "no results": "nn prj",
    "nothing found": "nn gmj",
    "nothing available": "nn jḫt wn",
    "coming soon": "r ḫpr m-ḫt nḏs",
    "sign up": "rḏj rn",
    "log out": "prj r rwty",
    "login": "ꜥq",
    "open explorer": "wn ptr wꜣt",
    "blockchain explorer": "ptr ṯs n ḏbwt",
    "copy to clipboard": "sš m wḥm m mḏꜣt nt ꜥ",
    "contact us": "dmḏ n.n",
    "select language": "stp mdw",
    "change language": "snj mdw",
    "account address": "st n ḥsb",
    "recipient address": "st n šsp",
    "node address": "st n sbꜣ",
    "node name": "rn n sbꜣ",
    "account name": "rn n ḥsb",
    "first name": "rn tpj",
    "last name": "rn pḥwj",
    "phone number": "ḥsb n mḏꜣt nt ꜥ",
    "mobile phone": "mḏꜣt nt ꜥ",
    "create account": "ḳmꜣ ḥsb",
    "import account": "jnj ḥsb r ẖnw",
    "restore access": "sꜥnḫ wn",
    "backup account": "jr šꜥt snnw n ḥsb",
    "wallet backup": "šꜥt snnw n pr ḥḏ",
    "backup password": "mdw n wn n šꜥt snnw",
    "wrong pin": "ḫtm PIN n mꜣꜥ",
    "wrong password": "mdw n wn n mꜣꜥ",
    "incorrect password": "mdw n wn n mꜣꜥ",
    "invalid password": "mdw n wn n mꜣꜥ",
    "transaction hash": "ḫtm n jrt swnt",
    "extrinsic hash": "ḫtm n jrt swnt",
    "transaction submitted": "jrt swnt hꜣb",
    "transaction rejected": "jrt swnt ḫsf",
    "send unavailable": "hꜣb nn wn",
    "network unavailable": "jꜣdt nt wꜣwt nn wn",
    "network connection": "dmḏ wꜣwt",
    "daily votes": "ḫrw n hrw nb",
    "vote history": "sšw n ḫrw",
    "vote history": "sšw n ḫrw",
    "recovery phrase": "ṯs mdw n sꜥnḫ",
    "secret passphrase": "ṯs mdw štꜣ",
    "secret raw seed": "prt štꜣ",
    "biometric authentication": "smn rn m ẖt",
    "system appearance": "ḳd n dmḏt",
    "dark mode": "ḳd kkw",
    "app settings": "smnt n mḏꜣt",
    "crypto accounts": "ḥsbw n ḫtm štꜣ",
    "referral program": "kꜣt n njs",
    "referral reward": "ḥzwt n njs",
    "referrer set": "njs smn",
    "available invitations": "njsw wn",
    "no available invitations": "nn njsw wn",
    "active farms": "ꜣḥwt ꜥnḫw",
    "farming details": "rḫt nb n ꜣḥt",
    "market algorithm": "hp n ḥsb n st swn",
    "swap fee": "bꜣkw n dbꜣ",
    "taker fee": "bꜣkw n šsp",
    "shares out": "psšw r rwty",
    "collateral out": "jḫt rdj r rwty",
    "test networks": "jꜣdt nt wꜣwt n smn",
}

# Security-critical and meaning-dense messages get clause-level translations.
# Each is intentionally concise, but preserves the operative condition and
# consequence of its English source.
# These two UX messages changed after the original catalog was generated.
# Bind reviewed clauses to exact source text so later copy edits need review.
REVIEWED_SOURCE_VALUES = {
    'import.account.message': 'Choose Recovery phrase for your saved words, or Raw seed for a private seed you exported. Choose Google only if you previously saved a cloud backup.',
    'onboarding.description': 'Send, receive, and swap assets on SORA. Create an account for a new recovery phrase, or import an account using a phrase you already have.',
}

KEY_TRANSLATIONS = {
    'import.account.message': 'stp ṯs mdw n sꜥnḫ n mdw.k sꜣw, r-pw prt štꜣ n prt štꜣ hꜣb.n.k r rwty. stp Google jr sꜣw.n.k šꜥt snnw Google m-bꜣḥ. jr nn šꜥt snnw Google, m stp Google',
    'onboarding.description': 'hꜣb jḫt, šsp jḫt, dbꜣ jḫt ḥr SORA. ḳmꜣ ḥsb n ṯs mdw n sꜥnḫ mꜣw, r-pw jnj ḥsb r ẖnw m ṯs mdw wn n.k m-bꜣḥ',

    "common.error.general.message": "jr.n ḥr smn btꜣ pn m pḥty nb. jr m wḥm m-ḫt",
    "common.error.internal.error.body": "jr.n ḥr smn btꜣ pn m pḥty nb. jr m wḥm m-ḫt",
    "connection.error.message": "mꜣꜣ dmḏ wꜣwt pt. jr m wḥm m-ḫt",
    "common.error.unauthorized.body": "mꜣꜣ dmḏ wꜣwt pt. jr m wḥm m-ḫt",
    "common.error.invalid.parameters.body": "mꜣꜣ dmḏ wꜣwt pt. jr m wḥm m-ḫt",
    "access.restore.words.error.message": "ṯs mdw ḥtr 12 r-pw 24 mdw",
    "access.restore.phrase.error.message": "smn ṯs mdw m 12 r-pw 24 mdw mꜣꜥ nb",
    "wallet.search.query.error.message": "ḥsb zšw n ḥḥj ḥtr m-m 3 ḥnꜥ 64",
    "common.error.seed.is.not.valid": "smn prt štꜣ m 64 zšw hex",
    "common.passphrase.body": "m ḳmꜣ ḥsb mꜣw m SORA šsp.k ṯs mdw n 24 mdw. ṯs mdw SORA n 12 ḥnꜥ 24 mdw rḫ jnj r ẖnw sꜣw rn pr ḥḏ tpj",
    "recovery.body.subtitle": "nn wꜣt r wn ḥsb jr mhj.k ṯs mdw",
    "logout.dialog.body": "jrt tn r dr ḥsb m mḏꜣt nt ꜥ tn. smn šꜥt snnw n ṯs mdw m-bꜣḥ",
    "mnemonic.text": "jr šꜥt snnw nn m mḏꜣt: sš ṯs mdw ḥr šꜥt sꜣw st m sꜣw",
    "mnemonic.alert.text": "ṯs mdw sꜥnḫ wn ḥsb. sš st; nn wꜣt n.n r sꜥnḫ ḥsb.k nn st",
    "screenshot.alert.text": "m jr zšw n ptr; ḫt bjn n rmṯw ky r šsp sn",
    "pincode.length.info.title": "smn ḫtm PIN n 6 ḥsbw",
    "pincode.length.info.message": "hp n sꜣw SORA sꜣꜣ n sꜣw.k. ḫtm PIN n 4 ḥsbw n wn. smn ḫtm PIN mꜣw n 6 ḥsbw",
    "backup.password.title": "mdw n wn r ḫtm šꜥt snnw Google. ḥtr rdj.k st m sꜥnḫ pr ḥḏ. ḥsb nḏs n mdw n wn 6 zšw",
    "backup.password.title.2": "mdw n wn r ḫtm šꜥt snnw Google. ḥtr rdj.k st m sꜥnḫ pr ḥḏ",
    "backup.password.requirments": "ḥsb nḏs 6 zšw. n sꜣw ꜥꜣ rdj zšw ꜥꜣw ḥsbw ḥnꜥ zšw nn n rn",
    "create.backup.password.warning.text": "rḫ.j ntt jr mhj.j mdw n wn nn wꜣt r šsp st m wḥm",
    "delete.backup.alert.description": "jr dr.k šꜥt snnw Google, ṯs mdw sš m ꜥ.k wꜥ r sꜥnḫ pr ḥḏ",
    "import.account.not.backed.up.alert.description": "jr tnm r-pw ṯꜣw mḏꜣt nt ꜥ.k, pr ḥḏ ḥnꜥ jḫt.k r ḥtm r nḥḥ",
    "export.account.details.backup.description": "jr ḥtm wn mḏꜣt nt ꜥ tn, jḫt.k r ḥtm nn šꜥt snnw",
    "export.protection.json.1": "jr ḥtm JSON n.j jḫt.j r ḥtm r nḥḥ",
    "export.protection.json.2": "jr rdj.j JSON n.j r rmṯ ky jḫt.j r ṯꜣw",
    "export.protection.json.3": "jrt n.j ds.j sꜣw JSON n.j",
    "export.protection.passphrase.1": "jr ḥtm ṯs mdw n.j jḫt.j r ḥtm r nḥḥ",
    "export.protection.passphrase.2": "jr rdj.j ṯs mdw n.j r rmṯ ky jḫt.j r ṯꜣw",
    "export.protection.passphrase.3": "jrt n.j ds.j sꜣw ṯs mdw n.j",
    "export.protection.seed.1": "jr ḥtm prt štꜣ n.j jḫt.j r ḥtm r nḥḥ",
    "export.protection.seed.2": "jr rdj.j prt štꜣ n.j r rmṯ ky jḫt.j r ṯꜣw",
    "export.protection.seed.3": "jrt n.j ds.j sꜣw prt štꜣ n.j",
    "node.details.genesis.validation.failed": "ḫtm tp n sbꜣ.k n mj ḫtm tp n jꜣdt nt wꜣwt",
    "pincode.last.try.subtitle": "rdj.n.k PIN n mꜣꜥ sp ꜥšꜣ. sp pn pḥwj m-bꜣḥ ḫtm mḏꜣt n %@",
    "wallet.send.existential.warning.message": "hꜣb.k r dr ḥsb m pr n ḏbwt ntt dmḏ jḫt r ḫr ẖr rdj n ꜥnḫ",
    "pending.transaction.recovery.required": "sꜥnḫ n jrt swnt m ꜣwt ḥtr. hꜣb ḫsf; jr šꜥt snnw r-pw hꜣb šꜥt n nḏ-ḥr m-bꜣḥ snj pr ḥḏ pn",
    "test.networks.description": "mꜣꜣ jḫt n Taira testnet ḥnꜥ jrt swnt. jḫt n testnet nn jsw ḥḏ",
    "swap.confirmation.screen.warning.balance.afterwards.transaction.is.too.small": "smn %@ wꜣḥ m-ḫt jrt swnt tn; jr nn, n rḫ.k jr jrt swnt ky",
    "confirn.supply.liquidity.first.provider.warning": "ntk rdj mw ḥḏ tpj. ḥsb m-m jḫt rdj.k r smn jsw n š pn",
    "polkaswap.maximum.sold.info": "jrt swnt r jr m wḥm jr jsw snj ꜥꜣ m bjn m-bꜣḥ smn",
    "polkaswap.minimum.received.info": "jrt swnt r jr m wḥm jr jsw snj ꜥꜣ m bjn m-bꜣḥ smn",
    "polkaswap.slippage.info": "jrt swnt r jr m wḥm jr jsw snj m bjn r psš pn",
    "polkaswap.network.fee.info": "bꜣkw n jꜣdt nt wꜣwt sꜣw sꜣꜣ dmḏt SORA ḥnꜥ jrt mn",
    "polkaswap.liquidity.fee.info": "psš n swn nb r rdjw mw ḥḏ mj ḥzwt n hp",
    "polkaswap.info.text.3": "jrt n.k ds.k jr hpw nb n tꜣ n hpw.k m jrt Polkaswap",
    "polkaswap.info.text.4": "rḫ.k ḳd ntt n Polkaswap tp-ꜥ; n smn mḥ, jrwt nhy r n jr mj ḳd",
    "polkaswap.info.text.5": "rḫ.k ḥnꜥ šsp.k m jb ḫt bjn n jrt Polkaswap, ḥnꜥ ḥtm jḫt",
    "polkaswap.info.text.6": "m šm nn šdj %%Polkaswap dbḥw ḥnꜥ wšbw%%, %%šꜥt Polkaswap ḥnꜥ hpw bꜣk%%, ḥnꜥ %%hp n sꜣw štꜣ%%",
    "tutorial.terms.and.conditions": "m ḳmꜣ ḥsb šsp.k hpw ḥnꜥ hp n sꜣw štꜣ",
    "tutorial.terms.and.conditions.1": "m rḏj rn šsp.k hpw ḥnꜥ hp n sꜣw štꜣ",
}

STRING_RE = re.compile(
    r'^\s*"(?P<key>(?:\\.|[^"])*)"\s*=\s*"(?P<value>(?:\\.|[^"])*)";\s*$'
)
TOKEN_RE = re.compile(
    r"[¤¶]\d+[¤¶]|%(?:\d+\$)?(?:@|s|d|li)|%%|\\n|[A-Za-z]+(?:['’][A-Za-z]+)?|"
    r"\d+(?:\.\d+)?|[^A-Za-z\d\s%¤¶\\]+|[%¤¶\\]|\s+"
)
FORMAT_RE = re.compile(r"%(?:\d+\$)?(?:@|s|d|li)|%%")
HIERO_RE = re.compile(r"[\U00013000-\U0001342F]")


def protect_literals(text: str) -> tuple[str, dict[str, str]]:
    protected: dict[str, str] = {}
    for index, literal in enumerate(sorted(LITERALS, key=len, reverse=True)):
        marker = f"¤{index}¤"
        if literal in text:
            text = text.replace(literal, marker)
            protected[marker] = literal
    return text, protected


def encode_hieroglyphs(transliteration: str) -> str:
    text, protected = protect_literals(transliteration)
    for index, token in enumerate(re.findall(r'\\n|\\"', text)):
        marker = f"¦{index}¦"
        text = text.replace(token, marker, 1)
        protected[marker] = token
    for index, token in enumerate(FORMAT_RE.findall(text)):
        marker = f"¥{index}¥"
        text = text.replace(token, marker, 1)
        protected[marker] = token
    encoded = "".join(SIGNS.get(character, character) for character in text)
    for marker, literal in protected.items():
        encoded = encoded.replace(marker, literal)
    return encoded


def apply_phrases(value: str) -> tuple[str, dict[str, str]]:
    # Longest first so a smaller phrase never consumes part of a larger one.
    protected: dict[str, str] = {}
    for index, (phrase, egyptian) in enumerate(
        sorted(PHRASES.items(), key=lambda item: len(item[0]), reverse=True)
    ):
        marker = f"¶{index}¶"
        before = value
        value = re.sub(
            rf"(?<![A-Za-z]){re.escape(phrase)}(?![A-Za-z])",
            f" {marker} ",
            value,
            flags=re.IGNORECASE,
        )
        if value != before:
            protected[marker] = egyptian
    return value, protected


def word_translation(word: str) -> str:
    lower = word.lower().replace("’", "'")
    if lower in STOP_WORDS:
        return ""
    if lower in WORDS:
        return WORDS[lower]
    # Conservative English morphology; this is used only after exact entries.
    for suffix in ("ingly", "edly", "ments", "ment", "ations", "ation", "ers", "ies", "ing", "ed", "es", "s"):
        if lower.endswith(suffix) and len(lower) > len(suffix) + 2:
            stem = lower[: -len(suffix)]
            candidates = (stem, stem + "e", stem + "y")
            for candidate in candidates:
                if candidate in WORDS:
                    return WORDS[candidate]
    # A genuinely absent modern modifier is represented as "other thing".
    # Unknowns are reported at generation time so this path remains reviewable.
    return "jḫt ky"


def translate_value(key: str, value: str, unknowns: Counter[str]) -> str:
    if key in REVIEWED_SOURCE_VALUES and value != REVIEWED_SOURCE_VALUES[key]:
        raise ValueError(f"English source changed for reviewed translation: {key}")
    if key in KEY_TRANSLATIONS:
        result = KEY_TRANSLATIONS[key]
        # Clause-level translations include their format tokens explicitly.
        return encode_hieroglyphs(result)

    if key.endswith("year.format") or key in {
        "this.year.format", "any.year.format", "finished.project.year.format"
    }:
        return value

    protected_value, literals = protect_literals(value)
    protected_value, phrases = apply_phrases(protected_value)
    output: list[str] = []

    for token in TOKEN_RE.findall(protected_value):
        if token in phrases:
            output.append(phrases[token])
            continue
        if token in literals:
            output.append(token)
            continue
        if FORMAT_RE.fullmatch(token) or token == "\\n" or token.isspace():
            output.append(token)
            continue
        if re.fullmatch(r"\d+(?:\.\d+)?", token):
            output.append(token)
            continue
        if re.fullmatch(r"[A-Za-z]+(?:['’][A-Za-z]+)?", token):
            translated = word_translation(token)
            if translated == "jḫt ky":
                unknowns[token.lower()] += 1
            output.append(translated)
            continue
        output.append(token)

    text = "".join(output)
    for marker, literal in literals.items():
        text = text.replace(marker, literal)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *([,;:.!?]) *", r"\1 ", text)
    text = text.replace(" \\n ", "\\n").replace("\\n ", "\\n").replace(" \\n", "\\n")
    text = text.strip()
    return encode_hieroglyphs(text)


def parse_catalog(path: Path) -> list[tuple[str, str]]:
    return parse_catalog_text(path.read_text(encoding="utf-8"))


def decoded_catalog_key(key: str) -> str:
    # Compare escaped spellings as the same key; reject ambiguous escape forms.
    try:
        return json.loads('"' + key + '"')
    except ValueError as error:
        raise ValueError("unsupported catalog key escape") from error


def parse_catalog_text(content: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    seen: set[str] = set()
    for line_number, line in enumerate(content.splitlines(), 1):
        match = STRING_RE.match(line)
        if match:
            key, value = match.group("key"), match.group("value")
            decoded_key = decoded_catalog_key(key)
            if not decoded_key or decoded_key in seen:
                raise ValueError(f"empty or duplicate catalog key on line {line_number}")
            seen.add(decoded_key)
            entries.append((key, value))
        elif line.strip() and not line.lstrip().startswith(("//", "/*", "*", "*/")):
            raise ValueError(f"unparsed source line {line_number}: {line}")
    return entries


def parse_source_catalog() -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
    content = SOURCE.read_text(encoding="utf-8")
    # Check duplicates across the boundary before parsing its two sections.
    parse_catalog_text(content)
    if content.splitlines().count(FALLBACK_SECTION) != 1:
        raise ValueError("expected one explicit English fallback section")
    core, fallback = content.split(FALLBACK_SECTION)
    translated_entries = parse_catalog_text(core)
    fallback_entries = parse_catalog_text(fallback)
    if not translated_entries or not fallback_entries:
        raise ValueError("empty translated or English fallback section")
    for key, value in fallback_entries:
        if key != value:
            raise ValueError(f"English fallback must preserve its literal key: {key}")
    if TARGET.exists():
        retained_keys = {decoded_catalog_key(key) for key, _ in parse_catalog(TARGET)}
        if retained_keys.intersection(decoded_catalog_key(key) for key, _ in fallback_entries):
            raise ValueError("an existing Egyptian translation cannot become English fallback")
    return translated_entries, fallback_entries


def placeholders(value: str) -> list[str]:
    return sorted(FORMAT_RE.findall(value))


def validate_bundled_font() -> None:
    for path, expected in (
        (FONT, FONT_SHA256),
        (FONT_LICENSE, FONT_LICENSE_SHA256),
    ):
        if not path.is_file():
            raise ValueError(f"missing bundled hieroglyph font artifact: {path}")
        observed = hashlib.sha256(path.read_bytes()).hexdigest()
        if observed != expected:
            raise ValueError(f"unexpected bundled hieroglyph font artifact: {path}")


def generate(check: bool) -> None:
    validate_bundled_font()
    entries, fallback_entries = parse_source_catalog()
    unknowns: Counter[str] = Counter()
    rendered: list[str] = [
        "/* Generated by generate-middle-egyptian-localization.py.",
        " * Normalized linear Middle Egyptian; see docs/localization/middle-egyptian-hieroglyphs.md. */",
    ]
    date_format_keys = {
        "this.year.format", "any.year.format", "finished.project.year.format",
    }
    hieroglyph_optional_keys = date_format_keys | {
        "project.details.favorite.voted.count",
        "ask.touchid.title", "asset.details", "asset.eth.name", "asset.val.fullname",
        "asset.xor.platform", "asset.eth.plaform", "wallet.soranet", "wallet.erc20",
        "asset.details.val", "tabbar.polkaswap.title", "invite.code.left.hours",
        "invite.code.left.minutes", "invite.code.left.seconds",
        "more.menu.sora.card.title", "pageTitle.Polkamarkt",
    }

    for key, english in entries:
        translated = translate_value(key, english, unknowns)
        if placeholders(english) != placeholders(translated):
            raise ValueError(
                f"placeholder mismatch for {key}: {placeholders(english)} != {placeholders(translated)}"
            )
        residual = translated
        for literal in sorted(LITERALS, key=len, reverse=True):
            residual = residual.replace(literal, "")
        residual = FORMAT_RE.sub("", residual)
        residual = residual.replace(r"\n", "").replace(r'\"', "")
        if key not in date_format_keys and re.search(r"[A-Za-z]", residual):
            raise ValueError(f"unprotected Latin text in translated value for {key}: {residual}")
        if key not in hieroglyph_optional_keys and not HIERO_RE.search(translated):
            raise ValueError(f"no Egyptian hieroglyph in translated value for {key}")
        escaped = translated.replace('"', '\\"')
        rendered.append(f'"{key}" = "{escaped}";')

    content = "\n".join(rendered) + "\n"
    if check:
        if not TARGET.exists() or TARGET.read_text(encoding="utf-8") != content:
            raise SystemExit(f"{TARGET} is not regenerated from {SOURCE}")
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_text(content, encoding="utf-8")

    print(f"validated {len(entries)} keys; {len(unknowns)} generic modern words")
    print(f"validated {len(fallback_entries)} explicit English fallback keys")
    if unknowns:
        summary = ", ".join(f"{word}({count})" for word, count in unknowns.most_common())
        print(f"review queue: {summary}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    generate(arguments.check)


if __name__ == "__main__":
    main()
