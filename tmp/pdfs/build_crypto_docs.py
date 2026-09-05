#!/usr/bin/env python3
"""Build the SORA Wallet ANSSI filing draft and supporting technical dossier."""

from __future__ import annotations

import copy
import hashlib
import os
from datetime import date
from pathlib import Path
from xml.etree import ElementTree as ET

from pypdf import PdfReader, PdfWriter
from pypdf.generic import BooleanObject, NameObject
from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
SOURCE_FORM = ROOT / "tmp/pdfs/anssi-crypto-declaration-form.pdf"
OUTPUT_DIR = ROOT / "output/pdf"
FORM_OUTPUT = OUTPUT_DIR / "SORA-Wallet-ANSSI-Annex-I-draft.pdf"
DOSSIER_OUTPUT = OUTPUT_DIR / "SORA-Wallet-cryptography-technical-dossier.pdf"

PINK = HexColor("#FF2E88")
DEEP = HexColor("#24152F")
INK = HexColor("#2D2633")
MUTED = HexColor("#6F6474")
PALE = HexColor("#F7F1F6")
LINE = HexColor("#D9CED8")
GREEN = HexColor("#217A55")
AMBER = HexColor("#9A6100")
WHITE = colors.white


FIELD_VALUES = {
    "ChoixFormalité": "Déclaration",
    "T_A1DenomiSociale": "Soramitsu Co., Ltd.",
    "T_A1NumSiret": "Non applicable - société japonaise",
    "T_A1Nation": "Japon",
    "T_A1Adresse1": "Link Square Shinjuku 16F",
    "T_A1Adresse2": "5-27-5 Sendagaya",
    "T_A1CodePostal": "151-0051",
    "T-A1Ville": "Shibuya-ku, Tokyo",
    "T_A1NumTel": "+81 50 5526 4670",
    "T_A1AdminNom": "Takemiya",
    "T_A1AdminPrenom": "Makoto",
    "T_A1AdminAdresse1": "Link Square Shinjuku 16F",
    "T_A1AdminAdresse2": "5-27-5 Sendagaya",
    "T_A1AdminPays": "Japon",
    "T_A1AdminVille": "Shibuya-ku, Tokyo",
    "T_A1AdminCodePostal": "151-0051",
    "T_A1AdminNumTel": "+81 50 5526 4670",
    "T_A1AdminEmail": "takemiya@soramitsu.co.jp",
    "Lst_A1AdminCivilite": "M.",
    "T_A1TechNom": "Takemiya",
    "T_A1TechPrenom": "Makoto",
    "T_A1TechAdresse1": "Link Square Shinjuku 16F",
    "T_A1TechAdresse2": "5-27-5 Sendagaya",
    "T_A1TechPays": "Japon",
    "T_A1TechVille": "Shibuya-ku, Tokyo",
    "T_A1TechCodePostal": "151-0051",
    "T_A1TechNumTel": "+81 50 5526 4670",
    "T_A1TechEmail": "takemiya@soramitsu.co.jp",
    "Lst_A1TechCivilite": "M.",
    "T_B1Marque": "SORA",
    "T_B1RefCommerciale": "Apple App ID 1457566711 - bundle co.jp.soramitsu.sora",
    "D_B1DateMiseMarche": "2026-08-14",
    "T_B1Fab": "Soramitsu Co., Ltd.",
    "T_B1DenomOrg": "Soramitsu Co., Ltd.",
    "T_B1Version": "3.8.7 (build 2026081101)",
    "T_B1Designation": "SORA Wallet: Polkaswap",
    "CB_B21Materiel": "0",
    "CB_B21Logiciel": "1",
    "T_B22Description": (
        "Application iOS non-dépositaire destinée au grand public. Elle permet de créer ou "
        "importer des comptes SORA, conserver localement les secrets, signer des transactions "
        "de chaîne, envoyer et recevoir des actifs numériques, échanger des jetons, fournir de "
        "la liquidité et participer au staking. Les clés privées ne sont pas détenues par le "
        "fournisseur. Le chiffrement applicatif protège les sauvegardes de portefeuille et les "
        "secrets; les signatures authentifient les transactions."
    ),
    "RB_B23Catégorie": "Envoi",
    "T_B23Autres": "",
    "T_B31Description": (
        "Confidentialité et intégrité des sauvegardes de comptes au moyen de NaCl SecretBox "
        "avec une clé dérivée par scrypt; dérivation de clés et authentification par fonctions "
        "de hachage et HMAC; création, vérification et dérivation de signatures sr25519, "
        "Ed25519, variante Iroha Ed25519/SHA3 publiée et ECDSA/secp256k1 pour les transactions "
        "SORA, Substrate et Iroha. "
        "Les communications réseau utilisent TLS fourni par iOS. Voir le dossier technique joint."
    ),
    "CB_B32Auth": "1",
    "CB_B32Integrite": "1",
    "CB_B32Confidentialite": "1",
    "CB_B32Signature": "1",
    "CB_B33IPSec": "0",
    "CB_B33SSH": "0",
    "CB_B33VOIP": "0",
    "CB_B33SSL": "1",
    "CB_B33Autres": "0",
    "T_B33Autres": "",
    "CB_CAnnexe3": "1",
    "T_CCommercialisation": (
        "Distribution mondiale au grand public par l'Apple App Store. Application gratuite "
        "installée sans contrat individuel ni personnalisation du code cryptographique."
    ),
    "T_CNonModifiable": (
        "Les algorithmes et paramètres sont compilés dans l'application signée. L'interface ne "
        "permet ni ajout d'algorithme ni modification du code cryptographique. L'installation et "
        "les mises à jour sont autonomes via l'App Store et ne nécessitent pas d'assistance "
        "technique importante du fournisseur."
    ),
    "T_FPrenom": "Makoto",
    "T_FNom": "Takemiya",
    "T_FQualite": "CEO - représentant habilité",
    "T_FSociete": "Soramitsu Co., Ltd.",
    "D_FDate": "",
    "Lst_FCivilite": "M.",
    "CB_EDocGen": "1",
    "CB_EKbis": "0",
    "CB_EBroCom": "1",
    "CB_EBroTech": "1",
    "CB_EManuelUtil": "1",
    "CB_EGuideAdmin": "0",
}


ALGORITHM_ROWS = [
    {
        "T_B34Algo": "NaCl SecretBox (XSalsa20-Poly1305)",
        "T_B34Mode": "AEAD SecretBox",
        "T_B34Taille": "256 bits",
        "T_B34Fonction": "Confidentialité et intégrité des sauvegardes",
    },
    {
        "T_B34Algo": "scrypt",
        "T_B34Mode": "N=32768, r=8, p=1",
        "T_B34Taille": "clé dérivée 256 bits",
        "T_B34Fonction": "Dérivation de clé depuis mot de passe",
    },
    {
        "T_B34Algo": "sr25519 / Schnorrkel",
        "T_B34Mode": "Ristretto255",
        "T_B34Taille": "secret 256 bits",
        "T_B34Fonction": "Signature et vérification de transactions",
    },
    {
        "T_B34Algo": "Ed25519 et variante Iroha publiée",
        "T_B34Mode": "SHA-512; Iroha SHA3-512 + préhachage SHA3-256",
        "T_B34Taille": "secret 256 bits",
        "T_B34Fonction": "Signature, vérification, dérivation et migration",
    },
    {
        "T_B34Algo": "ECDSA",
        "T_B34Mode": "secp256k1, signature récupérable",
        "T_B34Taille": "secret 256 bits",
        "T_B34Fonction": "Signature et vérification de transactions",
    },
]


def fill_xfa_form() -> None:
    reader = PdfReader(str(SOURCE_FORM))
    writer = PdfWriter()
    writer.clone_document_from_reader(reader)
    acro = writer.root_object[NameObject("/AcroForm")]
    xfa = acro[NameObject("/XFA")]
    datasets_stream = None
    for index in range(0, len(xfa), 2):
        if str(xfa[index]) == "datasets":
            datasets_stream = xfa[index + 1].get_object()
            break
    if datasets_stream is None:
        raise RuntimeError("ANSSI source form has no XFA datasets packet")

    xml_root = ET.fromstring(datasets_stream.get_data())
    form = None
    for node in xml_root.iter():
        if node.tag.split("}")[-1] == "FormulaireAnnexeI":
            form = node
            break
    if form is None:
        raise RuntimeError("ANSSI XFA datasets packet has no FormulaireAnnexeI")

    direct_children = {child.tag.split("}")[-1]: child for child in form}
    missing = sorted(set(FIELD_VALUES) - set(direct_children))
    if missing:
        raise RuntimeError(f"XFA fields missing from official form: {missing}")
    for name, value in FIELD_VALUES.items():
        direct_children[name].text = value

    table_algo = direct_children.get("TableAlgo")
    if table_algo is None:
        raise RuntimeError("Official form has no algorithm table")
    algo_nodes = [n for n in table_algo if n.tag.split("}")[-1] == "AlgoCrypto"]
    if len(algo_nodes) != len(ALGORITHM_ROWS):
        raise RuntimeError(f"Expected 5 algorithm rows, got {len(algo_nodes)}")
    for row_node, row_values in zip(algo_nodes, ALGORITHM_ROWS):
        row_children = {child.tag.split("}")[-1]: child for child in row_node}
        for name, value in row_values.items():
            row_children[name].text = value

    new_data = ET.tostring(xml_root, encoding="utf-8", xml_declaration=False)
    datasets_stream.set_data(new_data)
    acro[NameObject("/NeedAppearances")] = BooleanObject(True)
    writer.add_metadata(
        {
            "/Title": "ANSSI Annex I - SORA Wallet 3.8.7 - draft",
            "/Author": "Soramitsu Co., Ltd.",
            "/Subject": "Unsigned draft for French cryptography declaration",
            "/Keywords": "ANSSI, cryptography, declaration, SORA Wallet, draft",
        }
    )
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with FORM_OUTPUT.open("wb") as handle:
        writer.write(handle)


def p(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text, style)


class FilingDocTemplate(BaseDocTemplate):
    def __init__(self, filename: str, **kwargs):
        super().__init__(filename, **kwargs)
        frame = Frame(
            18 * mm,
            18 * mm,
            A4[0] - 36 * mm,
            A4[1] - 34 * mm,
            id="body",
            leftPadding=0,
            rightPadding=0,
            topPadding=8 * mm,
            bottomPadding=6 * mm,
        )
        self.addPageTemplates(PageTemplate(id="standard", frames=[frame], onPage=self._draw_page))

    @staticmethod
    def _draw_page(canvas, doc):
        canvas.saveState()
        page = canvas.getPageNumber()
        canvas.setStrokeColor(PINK)
        canvas.setLineWidth(1.2)
        canvas.line(18 * mm, A4[1] - 14 * mm, A4[0] - 18 * mm, A4[1] - 14 * mm)
        canvas.setFont("Helvetica-Bold", 8)
        canvas.setFillColor(DEEP)
        canvas.drawString(18 * mm, A4[1] - 11 * mm, "SORA WALLET - DOSSIER CRYPTOGRAPHIQUE")
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawRightString(A4[0] - 18 * mm, A4[1] - 11 * mm, "Version 3.8.7 - DRAFT")
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.5)
        canvas.line(18 * mm, 14 * mm, A4[0] - 18 * mm, 14 * mm)
        canvas.setFont("Helvetica", 7.5)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 9.5 * mm, "Confidentiel - dépôt réglementaire")
        canvas.drawRightString(A4[0] - 18 * mm, 9.5 * mm, f"Page {page}")
        canvas.restoreState()


def build_styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="CoverTitle",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=28,
            leading=31,
            textColor=DEEP,
            alignment=TA_LEFT,
            spaceAfter=8 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CoverKicker",
            parent=styles["Normal"],
            fontName="Helvetica-Bold",
            fontSize=10,
            leading=13,
            textColor=PINK,
            spaceAfter=5 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CoverSub",
            parent=styles["Normal"],
            fontName="Helvetica",
            fontSize=13,
            leading=18,
            textColor=MUTED,
            spaceAfter=10 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H1x",
            parent=styles["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=18,
            leading=22,
            textColor=DEEP,
            spaceBefore=2 * mm,
            spaceAfter=5 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="H2x",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12,
            leading=15,
            textColor=PINK,
            spaceBefore=5 * mm,
            spaceAfter=2.5 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Bodyx",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9.2,
            leading=13.2,
            textColor=INK,
            spaceAfter=2.5 * mm,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Smallx",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=7.4,
            leading=10.2,
            textColor=INK,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Tinyx",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=6.5,
            leading=8.4,
            textColor=INK,
        )
    )
    styles.add(
        ParagraphStyle(
            name="Statusx",
            parent=styles["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9.5,
            leading=13,
            textColor=AMBER,
            borderColor=HexColor("#E4B45D"),
            borderWidth=0.8,
            borderPadding=8,
            backColor=HexColor("#FFF8E8"),
            spaceAfter=6 * mm,
        )
    )
    return styles


def styled_table(data, widths, *, header=True, font_size=7.4, row_bgs=True):
    table = Table(data, colWidths=widths, repeatRows=1 if header else 0, hAlign="LEFT")
    commands = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.35, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 0), (-1, -1), font_size),
        ("TEXTCOLOR", (0, 0), (-1, -1), INK),
    ]
    if header:
        commands.extend(
            [
                ("BACKGROUND", (0, 0), (-1, 0), DEEP),
                ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("BOTTOMPADDING", (0, 0), (-1, 0), 5),
                ("TOPPADDING", (0, 0), (-1, 0), 5),
            ]
        )
    if row_bgs:
        start = 1 if header else 0
        for row in range(start, len(data)):
            if (row - start) % 2 == 1:
                commands.append(("BACKGROUND", (0, row), (-1, row), PALE))
    table.setStyle(TableStyle(commands))
    return table


def build_dossier() -> None:
    s = build_styles()
    body = s["Bodyx"]
    small = s["Smallx"]
    tiny = s["Tinyx"]
    doc = FilingDocTemplate(
        str(DOSSIER_OUTPUT),
        pagesize=A4,
        title="SORA Wallet - Dossier technique cryptographique",
        author="Soramitsu Co., Ltd.",
        subject="Support de déclaration ANSSI - version 3.8.7",
        creator="Soramitsu Co., Ltd.",
    )
    story = []

    story.extend(
        [
            Spacer(1, 25 * mm),
            p("ANNEXE TECHNIQUE / TECHNICAL ANNEX", s["CoverKicker"]),
            p("SORA Wallet:<br/>Polkaswap", s["CoverTitle"]),
            p(
                "Dossier cryptographique à l'appui d'une déclaration française auprès de l'ANSSI<br/>"
                "Cryptography dossier supporting a French ANSSI declaration",
                s["CoverSub"],
            ),
            p(
                "DRAFT - NON SIGNÉ - NON DÉPOSÉ. Ce document n'est ni une attestation ni une "
                "approbation de l'ANSSI. Il doit être accompagné du formulaire officiel Annex I "
                "signé, d'un justificatif d'immatriculation récent et des preuves de dépôt.",
                s["Statusx"],
            ),
            styled_table(
                [
                    [p("Produit", small), p("SORA Wallet: Polkaswap", small)],
                    [p("Version", small), p("3.8.7 - build 2026081101", small)],
                    [p("Identifiant", small), p("co.jp.soramitsu.sora - Apple App ID 1457566711", small)],
                    [p("Éditeur", small), p("Soramitsu Co., Ltd., Japon", small)],
                    [p("Révision source", small), p("d657f9ccc55ba1f9558c474229bc470375a71bfd", small)],
                    [p("Date du dossier", small), p("14 août 2026", small)],
                ],
                [38 * mm, 120 * mm],
                header=False,
                font_size=8,
            ),
            Spacer(1, 16 * mm),
            p(
                "Objet: décrire les fonctions cryptographiques incorporées dans l'application "
                "iOS, leur finalité, leurs paramètres et leur provenance logicielle. Le dossier "
                "ne contient aucun secret, clé privée, donnée utilisateur ou matériel de signature.",
                body,
            ),
            PageBreak(),
        ]
    )

    story.extend(
        [
            p("1. Déclarant et identification du produit", s["H1x"]),
            p("1.1 Déclarant", s["H2x"]),
            styled_table(
                [
                    [p("Champ", small), p("Valeur", small)],
                    [p("Raison sociale", small), p("Soramitsu Co., Ltd.", small)],
                    [p("Nationalité", small), p("Japon", small)],
                    [p("Adresse", small), p("Link Square Shinjuku 16F, 5-27-5 Sendagaya, Shibuya-ku, Tokyo 151-0051, Japon", small)],
                    [p("Téléphone", small), p("+81 50 5526 4670", small)],
                    [p("Contact administratif et technique", small), p("Makoto Takemiya - takemiya@soramitsu.co.jp", small)],
                    [p("SIRET", small), p("Non applicable - société constituée au Japon. Joindre un extrait récent du registre japonais ou équivalent étranger.", small)],
                ],
                [48 * mm, 110 * mm],
            ),
            p("1.2 Produit", s["H2x"]),
            styled_table(
                [
                    [p("Champ", small), p("Valeur", small)],
                    [p("Marque et désignation", small), p("SORA - SORA Wallet: Polkaswap", small)],
                    [p("Type", small), p("Logiciel - application iOS grand public", small)],
                    [p("Version déclarée", small), p("3.8.7 (build 2026081101)", small)],
                    [p("Référence commerciale", small), p("Apple App ID 1457566711; bundle co.jp.soramitsu.sora", small)],
                    [p("Mise sur le marché", small), p("14/08/2026 pour cette version, date prévisionnelle sous réserve des formalités; versions antérieures déjà distribuées.", small)],
                    [p("Canal de distribution", small), p("Apple App Store et TestFlight", small)],
                    [p("Catégorie", small), p("Finance - portefeuille non-dépositaire et fonctions Polkaswap", small)],
                ],
                [48 * mm, 110 * mm],
            ),
            p("1.3 Finalité fonctionnelle", s["H2x"]),
            p(
                "SORA Wallet est un portefeuille non-dépositaire: l'utilisateur crée ou importe "
                "un compte, conserve les secrets sur son appareil, signe localement des "
                "transactions et diffuse les transactions signées aux réseaux pris en charge. "
                "L'application permet notamment l'affichage d'actifs, les transferts, les swaps, "
                "la fourniture de liquidité, le staking et l'export chiffré de sauvegardes. "
                "Soramitsu ne reçoit pas les clés privées de l'utilisateur dans ce modèle.",
                body,
            ),
            PageBreak(),
        ]
    )

    story.extend(
        [
            p("2. Périmètre cryptographique", s["H1x"]),
            p("2.1 Fonctions mises en oeuvre", s["H2x"]),
            styled_table(
                [
                    [p("Fonction", small), p("Usage dans le produit", small), p("Données concernées", small)],
                    [p("Confidentialité", small), p("Chiffrement authentifié des exports et sauvegardes de comptes; chiffrement réseau TLS fourni par iOS.", small), p("Secrets de compte, métadonnées de sauvegarde, trafic réseau.", small)],
                    [p("Intégrité", small), p("Authentification de sauvegarde, hachage de transaction, vérification de preuve et signature.", small), p("Messages, payloads, transactions et sauvegardes.", small)],
                    [p("Authentification", small), p("HMAC/KDF et vérification de possession de clé; authentification de transport TLS.", small), p("Contenus sauvegardés et sessions réseau.", small)],
                    [p("Signature", small), p("Signature locale et vérification de transactions SORA/Substrate/Iroha.", small), p("Payloads de transactions et challenges.", small)],
                ],
                [33 * mm, 75 * mm, 50 * mm],
            ),
            p("2.2 Flux de données simplifié", s["H2x"]),
            styled_table(
                [
                    [p("Étape", small), p("Traitement", small), p("Sortie", small)],
                    [p("Création/import", small), p("Mnemonic ou seed converti en matériel de clé via KDF et dérivation spécifique au réseau.", small), p("Clé privée protégée localement; clé publique et adresse.", small)],
                    [p("Signature", small), p("Le payload est éventuellement haché puis signé localement en sr25519, Ed25519, variante Iroha Ed25519/SHA3 publiée ou ECDSA/secp256k1.", small), p("Transaction signée; aucun secret transmis.", small)],
                    [p("Sauvegarde", small), p("scrypt dérive une clé de 256 bits; NaCl SecretBox chiffre et authentifie le JSON de comptes.", small), p("Blob chiffré comprenant sel, paramètres, nonce et texte chiffré.", small)],
                    [p("Réseau", small), p("HTTPS/WSS avec TLS pris en charge par les bibliothèques système iOS.", small), p("Requêtes API et transactions signées.", small)],
                ],
                [27 * mm, 88 * mm, 43 * mm],
            ),
            p("2.3 Gestion des clés", s["H2x"]),
            p(
                "Les secrets de compte sont créés ou importés par l'utilisateur et utilisés sur "
                "l'appareil. Les octets sensibles sont explicitement effacés après les opérations "
                "de signature dans les chemins modernisés. Les exports multiples utilisent un sel "
                "aléatoire de 32 octets, scrypt N=32768, r=8, p=1, un nonce aléatoire et une clé "
                "de chiffrement de 256 bits. Les nombres aléatoires proviennent de "
                "SecRandomCopyBytes fourni par iOS.",
                body,
            ),
            PageBreak(),
        ]
    )

    crypto_rows = [
        [p("Algorithme / protocole", tiny), p("Mode / paramètres maximaux", tiny), p("Finalité", tiny), p("Origine", tiny)],
        [p("NaCl SecretBox", tiny), p("XSalsa20-Poly1305; clé 256 bits; nonce 192 bits", tiny), p("Chiffrement authentifié des sauvegardes", tiny), p("TweetNaCl Swift 1.1.0, lié à l'app", tiny)],
        [p("scrypt", tiny), p("N=32768, r=8, p=1; sortie 256 bits", tiny), p("Dérivation de clé de sauvegarde", tiny), p("Implémentation C IrohaCrypto, liée à l'app", tiny)],
        [p("sr25519 / Schnorrkel", tiny), p("Ristretto255; secret/seed 256 bits; signature 512 bits", tiny), p("Signature Substrate/SORA et dérivation", tiny), p("sr25519lib binaire, lié à l'app", tiny)],
        [p("Ed25519", tiny), p("Edwards25519; seed 256 bits; SHA-512; signature 512 bits", tiny), p("Signature Iroha/Substrate et dérivation", tiny), p("libed25519 binaire, lié à l'app", tiny)],
        [p("Iroha Ed25519/SHA3 publié", tiny), p("Edwards25519 ref10; SHA3-512 interne; chemin migration préhaché SHA3-256", tiny), p("Signature d'identité dans le flux de migration", tiny), p("Hyperledger iroha-ed25519 1.3.0, source publique; binaire lié", tiny)],
        [p("ECDSA secp256k1", tiny), p("Clé privée 256 bits; signature récupérable compacte", tiny), p("Signature de transactions compatibles ECDSA", tiny), p("secp256k1.swift 0.1.7, lié à l'app", tiny)],
        [p("BLAKE2b", tiny), p("Sorties 128/256/512 bits selon usage", tiny), p("Hachage de payload, identité et checksum", tiny), p("blake2lib binaire, lié à l'app", tiny)],
        [p("Keccak-256", tiny), p("Sortie 256 bits", tiny), p("Adresses et données Ethereum", tiny), p("Implémentation C vendue avec l'app", tiny)],
        [p("SHA-256 / SHA-512", tiny), p("Sorties 256/512 bits", tiny), p("Hachage, Ed25519, HMAC et KDF", tiny), p("IrohaCrypto et CommonCrypto/iOS", tiny)],
        [p("HMAC-SHA-256 / HMAC-SHA-512", tiny), p("Clés de longueur variable", tiny), p("Authentification, dérivation SLIP-0010", tiny), p("CryptoKit/CommonCrypto iOS", tiny)],
        [p("PBKDF2-HMAC-SHA-512", tiny), p("2048 itérations; sortie 512 bits", tiny), p("BIP-39 seed", tiny), p("CommonCrypto iOS", tiny)],
        [p("AES-GCM", tiny), p("Clé 256 bits dans le chemin de migration", tiny), p("Scellement d'artefacts de migration", tiny), p("CryptoKit iOS", tiny)],
        [p("TLS", tiny), p("Versions/suites négociées par iOS", tiny), p("Confidentialité et intégrité du transport", tiny), p("URLSession/Network.framework iOS", tiny)],
    ]
    story.extend(
        [
            p("3. Inventaire des algorithmes et protocoles", s["H1x"]),
            p(
                "Le tableau distingue les primitives incorporées dans l'application de celles "
                "fournies par le système d'exploitation Apple. Les tailles indiquées décrivent "
                "les paramètres maximaux observés dans la version déclarée; elles ne constituent "
                "pas une estimation de niveau de sécurité.",
                body,
            ),
            styled_table(crypto_rows, [38 * mm, 42 * mm, 46 * mm, 32 * mm], header=True, font_size=6.5),
            Spacer(1, 4 * mm),
            p(
                "Caractère publié: les primitives de confidentialité incorporées sont publiées "
                "et documentées. sr25519/Schnorrkel est un schéma publié utilisé dans "
                "l'écosystème Substrate. Le chemin de migration Iroha utilise aussi une variante "
                "de signature publiée par Hyperledger: Edwards25519 ref10 avec SHA3-512, précédée "
                "dans l'application d'un préhachage SHA3-256. Cette variante n'est pas secrète ni "
                "propriétaire, mais elle n'est pas l'Ed25519 exact défini par la RFC 8032; elle est "
                "donc déclarée explicitement ici.",
                body,
            ),
            PageBreak(),
        ]
    )

    evidence_rows = [
        [p("Élément", tiny), p("Preuve dans le dépôt", tiny)],
        [p("Sauvegarde SecretBox + scrypt", tiny), p("SoraPassport/Common/Crypto/KeystoreExportWrapper.swift:108-135; SoraPassport/Common/Crypto/ScryptParameters.swift:8-32", tiny)],
        [p("Signatures sr25519/Ed25519/ECDSA", tiny), p("SoraPassport/Common/Crypto/SigningWrapper.swift:154-179, 259-274; VendorPackages/shared-features-spm/Sources/IrohaCrypto/Classes/{sr25519,ed25519,secp256k1}", tiny)],
        [p("Variante Iroha Ed25519/SHA3", tiny), p("SoraPassport/ModulesRedesign/Migration/MigrationService.swift:654-674; SoraPassport/Common/Crypto/IRSigningDecorator.swift:63-65,79-81; VendorPackages/shared-features-spm/Sources/IrohaCrypto/Classes/Iroha/IRIrohaSigner.m:28-45 et NSData+SHA3.m:17-32", tiny)],
        [p("BLAKE2b", tiny), p("SoraPassport/Common/Crypto/SigningWrapperProtocol.swift:97; VendorPackages/shared-features-spm/Sources/IrohaCrypto/Classes/blake2/NSData+Blake2.m:13-83", tiny)],
        [p("Keccak-256 / secp256k1", tiny), p("VendorPackages/shared-features-spm/Sources/SSFCrypto/Classes/Data+Keccak.swift:9-34; Data+Ethereum.swift:2-67", tiny)],
        [p("PBKDF2/HMAC-SHA-512/Ed25519", tiny), p("SoraPassport/Common/Model/WalletNetworkModel.swift:3540-3740", tiny)],
        [p("AES-GCM / HMAC-SHA-256", tiny), p("SoraPassport/Common/MigrationEvidence/RetainedMigrationEvidenceHarness.swift:1245-1300, 1875-1912", tiny)],
        [p("Dépendances cryptographiques", tiny), p("VendorPackages/shared-features-spm/Package.swift:56-57, 69-89, 181-203", tiny)],
        [p("Version / identifiant", tiny), p("SoraPassport/Configs/SoraPassport.release.xcconfig:2; SoraPassport.xcodeproj/project.pbxproj (bundle co.jp.soramitsu.sora)", tiny)],
    ]
    story.extend(
        [
            p("4. Provenance et éléments de preuve", s["H1x"]),
            p("4.1 Références de code auditées", s["H2x"]),
            styled_table(evidence_rows, [43 * mm, 115 * mm], header=True, font_size=6.7),
            p("4.2 Dépendances principales", s["H2x"]),
            styled_table(
                [
                    [p("Composant", tiny), p("Version / forme", tiny), p("Usage", tiny)],
                    [p("TweetNaCl Swift wrapper", tiny), p("1.1.0 - SwiftPM", tiny), p("NaCl SecretBox", tiny)],
                    [p("secp256k1.swift", tiny), p("0.1.7 - SwiftPM", tiny), p("ECDSA/secp256k1", tiny)],
                    [p("IrohaCrypto", tiny), p("source + xcframeworks vendus", tiny), p("scrypt, Ed25519, variante Ed25519/SHA3 publiée, sr25519, BLAKE2b, secp256k1", tiny)],
                    [p("CryptoKit/CommonCrypto", tiny), p("iOS 16+", tiny), p("AES-GCM, SHA, HMAC, PBKDF2, Curve25519", tiny)],
                ],
                [54 * mm, 45 * mm, 59 * mm],
                header=True,
                font_size=6.8,
            ),
            p("4.3 Reproductibilité", s["H2x"]),
            p(
                "Le build TestFlight 2026081101 a été produit à partir de la révision Git "
                "d657f9ccc55ba1f9558c474229bc470375a71bfd. Les cinq modifications locales du "
                "14/08/2026 présentes dans l'arbre de travail ne figurent pas dans ce build "
                "déjà livré à Apple. Le présent inventaire vise donc le binaire 3.8.7 "
                "(2026081101), et devra être réévalué si un nouveau binaire modifie le périmètre "
                "cryptographique.",
                body,
            ),
            PageBreak(),
        ]
    )

    story.extend(
        [
            p("5. Classification et distribution", s["H1x"]),
            p("5.1 France", s["H2x"]),
            p(
                "Le produit est disponible sur l'App Store français. Pour la version déclarée, "
                "le dossier retient le régime de déclaration d'un moyen de cryptologie et ne "
                "revendique pas automatiquement l'exemption des équipements bancaires. Cette "
                "exemption est étroite: elle suppose notamment un moyen spécialement conçu et "
                "limité aux opérations bancaires ou financières et une capacité cryptographique "
                "non accessible à l'utilisateur. Un portefeuille non-dépositaire avec gestion de "
                "seed, clés et signatures n'est pas explicitement classé comme exempt par les "
                "sources publiques consultées.",
                body,
            ),
            p("5.2 Classement grand public demandé", s["H2x"]),
            styled_table(
                [
                    [p("Critère", small), p("Justification", small)],
                    [p("Marché", small), p("Distribution gratuite au grand public par l'Apple App Store dans de nombreux pays.", small)],
                    [p("Cryptographie non aisément modifiable", small), p("Algorithmes compilés dans une application signée; aucune interface de plug-in ou de script permettant de les remplacer.", small)],
                    [p("Installation autonome", small), p("Installation et mises à jour via l'App Store; création/import de compte en libre-service; aucune assistance importante nécessaire.", small)],
                ],
                [45 * mm, 113 * mm],
            ),
            p("5.3 Déclaration Apple", s["H2x"]),
            p(
                "Réponses techniques retenues pour le binaire: (1) sélectionner uniquement "
                "« algorithmes standard, non exclusivement fournis par le système Apple »; "
                "ne pas sélectionner « les deux »; (2) distribution en France: oui. Ce classement "
                "s'appuie sur la définition publiée "
                "par Apple et le BIS: la cryptographie dite non standard est propriétaire ou non "
                "publiée, notamment lorsqu'elle n'est ni adoptée par un organisme reconnu ni "
                "autrement publiée. La variante Iroha est publique et limitée à la signature; "
                "elle est néanmoins détaillée pour transparence. Dans App Store Connect, ces "
                "réponses déclenchent l'exigence d'une déclaration française. "
                "Après approbation par Apple, le code de conformité fourni devra être ajouté au "
                "projet sous la clé ITSEncryptionExportComplianceCode. La clé "
                "ITSAppUsesNonExemptEncryption doit refléter le résultat de la revue Apple.",
                body,
            ),
            p("5.4 Limites", s["H2x"]),
            p(
                "Ce dossier est une description technique préparatoire et ne constitue pas un "
                "avis juridique. Il ne remplace ni la signature d'un représentant habilité, ni "
                "l'extrait de registre de la société, ni le récépissé ou l'attestation de l'ANSSI, "
                "ni la décision de revue d'Apple.",
                body,
            ),
            PageBreak(),
        ]
    )

    story.extend(
        [
            p("6. Pièces et procédure de dépôt", s["H1x"]),
            p("6.1 Pièces à préparer", s["H2x"]),
            styled_table(
                [
                    [p("Pièce", small), p("État", small), p("Action", small)],
                    [p("Formulaire officiel Annex I électronique", small), p("Prérempli", small), p("Ouvrir dans Adobe Acrobat Reader, contrôler tous les champs, puis sauvegarder.", small)],
                    [p("Copie signée du formulaire", small), p("Manquante", small), p("Makoto Takemiya ou un autre représentant habilité doit dater et signer, puis produire un PDF scanné.", small)],
                    [p("Dossier technique", small), p("Préparé", small), p("Joindre le présent PDF.", small)],
                    [p("Présentation générale / brochure commerciale / guide utilisateur", small), p("Couverte en synthèse", small), p("Joindre aussi les documents publics existants s'ils sont disponibles.", small)],
                    [p("Extrait du registre japonais de moins de trois mois", small), p("Manquant", small), p("Obtenir et joindre l'équivalent étranger du Kbis.", small)],
                    [p("Preuve de dépôt ANSSI", small), p("À obtenir", small), p("Conserver l'accusé de réception; joindre l'attestation de déclaration lorsqu'elle est délivrée.", small)],
                ],
                [61 * mm, 26 * mm, 71 * mm],
            ),
            p("6.2 Envoi électronique ANSSI", s["H2x"]),
            p(
                "Destinataire: <b>controle@ssi.gouv.fr</b><br/>"
                "Objet exact: <b>[formalités] SORA - SORA Wallet: Polkaswap</b><br/>"
                "Pièces jointes: formulaire électronique sauvegardé; copie signée scannée; "
                "présent dossier technique; extrait de registre récent; autres brochures ou guides disponibles.",
                body,
            ),
            p("6.3 Téléversement App Store Connect", s["H2x"]),
            p(
                "Ne pas présenter ce brouillon comme une approbation. Le paquet le plus robuste "
                "pour Apple réunit le formulaire Annex I signé, la preuve de son dépôt auprès de "
                "l'ANSSI et, dès réception, l'attestation de déclaration ANSSI. Apple indique "
                "qu'une revue complète prend généralement environ deux jours ouvrés lorsque les "
                "informations sont suffisantes.",
                body,
            ),
            p("6.4 Contrôle avant signature", s["H2x"]),
            p(
                "Le représentant habilité doit confirmer la raison sociale, le numéro de registre "
                "étranger, les coordonnées, la date de mise sur le marché, le périmètre de la "
                "version 3.8.7, l'inventaire des algorithmes et la demande de classement grand "
                "public. Toute correction doit être reportée dans le formulaire électronique et "
                "la copie signée.",
                body,
            ),
            PageBreak(),
        ]
    )

    refs = [
        ("ANSSI - Formulaires de contrôle réglementaire sur la cryptographie", "https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-reglementaire-cryptographie-formulaires/"),
        ("ANSSI - Démarches relatives à un moyen de cryptologie", "https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-reglementaire-cryptographie-demarches/"),
        ("Légifrance - Décret n°2007-663 du 2 mai 2007", "https://www.legifrance.gouv.fr/loda/id/JORFTEXT000000646995"),
        ("Légifrance - Arrêté du 29 janvier 2015 (forme et contenu du dossier)", "https://www.legifrance.gouv.fr/loda/id/JORFTEXT000030255024/"),
        ("Apple - Export compliance documentation for encryption", "https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/"),
        ("Apple - Determine and upload app encryption documentation", "https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation"),
        ("Apple - Overview of export compliance", "https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance"),
        ("BIS - Définition de la cryptographie non standard, 740.17(b)(3)", "https://www.bis.gov/learn-support/encryption-controls/license-exception-enc-740.17-b-3"),
        ("BIS - Cryptography for Data Confidentiality", "https://www.bis.gov/learn-support/encryption-controls/cryptography-for-data-confidentiality"),
        ("IETF RFC 7914 - scrypt", "https://www.rfc-editor.org/rfc/rfc7914"),
        ("IETF RFC 8032 - Ed25519", "https://www.rfc-editor.org/rfc/rfc8032"),
        ("Hyperledger Iroha - implémentation Ed25519 à hachage interchangeable", "https://github.com/hyperledger-iroha/iroha-ed25519"),
        ("NIST SP 800-38D - AES-GCM", "https://csrc.nist.gov/pubs/sp/800/38/d/final"),
        ("Schnorrkel / sr25519 specification", "https://github.com/w3f/schnorrkel"),
        ("sr25519 public implementation lineage", "https://github.com/Warchant/sr25519-crust"),
        ("TweetNaCl / NaCl secretbox publication", "https://tweetnacl.cr.yp.to/"),
        ("TweetNaCl Swift wrapper source", "https://github.com/bitmark-inc/tweetnacl-swiftwrap"),
    ]
    story.extend(
        [
            p("7. Références", s["H1x"]),
            p(
                "Sources réglementaires, normes et publications techniques consultées. Les URL "
                "sont écrites en clair pour rester exploitables dans une copie imprimée.",
                body,
            ),
        ]
    )
    ref_data = [[p("Source", tiny), p("URL", tiny)]]
    for label, url in refs:
        ref_data.append([p(label, tiny), p(url, tiny)])
    story.append(styled_table(ref_data, [62 * mm, 96 * mm], header=True, font_size=6.3))
    story.extend(
        [
            Spacer(1, 8 * mm),
            p("8. Validation du document", s["H1x"]),
            styled_table(
                [
                    [p("Contrôle", small), p("Valeur", small)],
                    [p("Document", small), p("SORA Wallet cryptography technical dossier", small)],
                    [p("Version", small), p("3.8.7 - build 2026081101", small)],
                    [p("Révision", small), p("d657f9ccc55ba1f9558c474229bc470375a71bfd", small)],
                    [p("Date", small), p("14/08/2026", small)],
                    [p("Statut", small), p("DRAFT - signature et dépôt ANSSI requis", small)],
                ],
                [45 * mm, 113 * mm],
            ),
        ]
    )

    doc.build(story)


def validate_outputs() -> None:
    form_reader = PdfReader(str(FORM_OUTPUT))
    xfa = form_reader.trailer["/Root"]["/AcroForm"]["/XFA"]
    datasets = None
    for index in range(0, len(xfa), 2):
        if str(xfa[index]) == "datasets":
            datasets = xfa[index + 1].get_object().get_data()
            break
    if datasets is None:
        raise RuntimeError("Filled form lost XFA datasets")
    xml_root = ET.fromstring(datasets)
    values = {}
    table_rows = []
    for node in xml_root.iter():
        local = node.tag.split("}")[-1]
        if local in FIELD_VALUES:
            values[local] = node.text or ""
        if local == "AlgoCrypto":
            table_rows.append({child.tag.split("}")[-1]: child.text or "" for child in node})
    for name, expected in FIELD_VALUES.items():
        actual = values.get(name)
        if actual != expected:
            raise RuntimeError(f"XFA validation failed for {name}: {actual!r} != {expected!r}")
    if table_rows != ALGORITHM_ROWS:
        raise RuntimeError("XFA algorithm table validation failed")
    if form_reader.is_encrypted:
        raise RuntimeError("Filled form unexpectedly encrypted")

    dossier_reader = PdfReader(str(DOSSIER_OUTPUT))
    if len(dossier_reader.pages) < 7:
        raise RuntimeError("Technical dossier unexpectedly short")
    extracted = "\n".join(page.extract_text() or "" for page in dossier_reader.pages)
    for expected in [
        "SORA Wallet",
        "NaCl SecretBox",
        "sr25519",
        "NON SIGNÉ",
        "controle@ssi.gouv.fr",
        "d657f9ccc55ba1f9558c474229bc470375a71bfd",
    ]:
        if expected not in extracted:
            raise RuntimeError(f"Technical dossier missing expected text: {expected}")

    for path in (FORM_OUTPUT, DOSSIER_OUTPUT):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        print(f"{path}: {path.stat().st_size} bytes sha256={digest}")


def main() -> None:
    if not SOURCE_FORM.exists():
        raise SystemExit(f"Missing official ANSSI source form: {SOURCE_FORM}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    fill_xfa_form()
    build_dossier()
    validate_outputs()


if __name__ == "__main__":
    main()
