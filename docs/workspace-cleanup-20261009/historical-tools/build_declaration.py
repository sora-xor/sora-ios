from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from pypdf import PdfReader

ROOT = Path('/Users/takemiyamakoto/dev/sora-wallet')
OUT = ROOT / 'output/pdf/SORA-Wallet-France-Cryptography-Declaration-2026090601.pdf'
TMP = ROOT / 'tmp/pdfs/france-declaration-2026090601'
COMMIT = 'fabcd06ef3d3324b16c1ee076d0300704f1970c3'
NAVY = colors.HexColor('#173448')
GRAY = colors.HexColor('#52616B')
LIGHT = colors.HexColor('#EDF2F5')
RULE = colors.HexColor('#CCD7DE')

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name='TitleFR', fontName='Helvetica-Bold', fontSize=23, leading=27, textColor=NAVY, spaceAfter=14))
styles.add(ParagraphStyle(name='SubFR', fontName='Helvetica', fontSize=11, leading=15, textColor=GRAY, spaceAfter=16))
styles.add(ParagraphStyle(name='HFR', fontName='Helvetica-Bold', fontSize=12, leading=16, textColor=NAVY, spaceBefore=12, spaceAfter=6))
styles.add(ParagraphStyle(name='BodyFR', fontName='Helvetica', fontSize=9.5, leading=13.6, spaceAfter=8))
styles.add(ParagraphStyle(name='SmallFR', fontName='Helvetica', fontSize=8.2, leading=11.6, textColor=GRAY, spaceAfter=5, wordWrap='CJK'))
styles.add(ParagraphStyle(name='CellFR', fontName='Helvetica', fontSize=8.7, leading=12.1, spaceAfter=0))
styles.add(ParagraphStyle(name='LabelFR', fontName='Helvetica-Bold', fontSize=8.6, leading=12.1, textColor=NAVY, spaceAfter=0))
styles.add(ParagraphStyle(name='KickerFR', fontName='Helvetica-Bold', fontSize=8.3, leading=11, textColor=GRAY, spaceAfter=10))

story = []
def p(text, style='BodyFR'):
    return Paragraph(text, styles[style])
def add(text, style='BodyFR'):
    story.append(p(text, style))
def heading(text):
    add(text, 'HFR')
def rows(items, widths=(133, 358)):
    data = [[p(a, 'LabelFR'), p(b, 'CellFR')] for a, b in items]
    table = Table(data, colWidths=widths, hAlign='LEFT')
    table.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('BACKGROUND', (0,0), (0,-1), LIGHT),
        ('LINEBELOW', (0,0), (-1,-1), .35, RULE),
        ('LEFTPADDING', (0,0), (-1,-1), 9),
        ('RIGHTPADDING', (0,0), (-1,-1), 9),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(table)
    story.append(Spacer(1, 8))

add('SORAMITSU CO., LTD.  /  6 SEPTEMBRE 2026', 'KickerFR')
add('Déclaration technique<br/>de cryptologie', 'TitleFR')
add("SORA Wallet: Polkaswap<br/>Déclaration de l'éditeur - distribution en France", 'SubFR')
rows([
    ('Produit et plateforme', 'SORA Wallet: Polkaswap pour iOS'),
    ('Version examinée', '<b>3.8.7 (2026090601)</b>'),
    ('Éditeur', 'Soramitsu Co., Ltd. - Japon'),
    ('Identifiants Apple', 'App ID : 1457566711<br/>Bundle ID : co.jp.soramitsu.sora'),
    ('Source du build', f'{COMMIT}'),
    ('Distribution prévue', 'TestFlight et distribution en France : oui'),
])
heading('Objet du logiciel')
add("SORA Wallet est un portefeuille non dépositaire. Il permet de créer ou d'importer des comptes, de signer des transactions blockchain et d'envoyer, recevoir ou échanger des actifs numériques. Il prend en charge la sauvegarde chiffrée de comptes et des sessions de connexion avec des applications compatibles.")
heading("Déclaration de l'éditeur")
add("L'éditeur confirme l'utilisation de primitives cryptographiques publiques et de bibliothèques existantes ; aucun algorithme secret ou propriétaire n'est déclaré. Les fonctions observées dans le code du build identifié ci-dessus sont détaillées dans l'annexe. Les primitives fournies par iOS et celles intégrées à l'application sont distinguées.")
heading('Nature du document')
add("Ce dossier décrit le produit et ses mécanismes cryptographiques pour examen. Il constitue une déclaration technique de l'éditeur, et <b>ne constitue pas une attestation d'approbation délivrée par l'ANSSI</b>. Aucun numéro de déclaration, récépissé, signature de représentant ou approbation administrative n'est revendiqué dans ce document.")
add("Document limité au build identifié. Il ne contient aucune phrase de récupération, clé privée d'utilisateur, donnée de portefeuille ou secret de signature.", 'SmallFR')

story.append(PageBreak())
add('ANNEXE TECHNIQUE  /  CONFIDENTIALITÉ ET DÉRIVATION', 'KickerFR')
add('Protection des données', 'TitleFR')
rows([
    ('Sauvegardes de comptes', '<b>XSalsa20-Poly1305</b> : clé de 256 bits, nonce de 192 bits. Implémentation intégrée TweetNaClSwift. Le mot de passe de sauvegarde est utilisé pour dériver la clé ; il ne constitue pas une clé de signature blockchain. [S1]'),
    ('Dérivation de sauvegarde', '<b>scrypt</b> : paramètres par défaut à l\'export N=32768, r=8, p=1 ; sel de 32 octets, sortie de 32 octets. L\'import lit les paramètres stockés dans le fichier ; ces valeurs d\'export ne sont pas présentées comme une limite universelle d\'import. Implémentation IrohaCrypto intégrée. [S1]'),
    ('Sessions IrohaConnect', '<b>X25519</b> pour l\'accord de clé ; <b>HKDF-SHA256</b> pour deux clés directionnelles de 256 bits ; <b>ChaCha20-Poly1305</b> pour le chiffrement authentifié, nonce de 96 bits et tag de 128 bits. Ces opérations utilisent Apple CryptoKit. Un sel lié à la session est calculé avec BLAKE2b-256. [S2]'),
    ('Transport réseau', '<b>TLS</b> est fourni par les services réseau d\'iOS, notamment URLSession et Network. La version et les suites effectivement négociées dépendent d\'iOS et du serveur distant ; aucune suite fixe n\'est attestée ici.'),
    ('Dérivation Nexus', '<b>BIP39 / PBKDF2-HMAC-SHA512</b>, 2048 itérations, sortie de 64 octets ; dérivation renforcée Ed25519 suivant SLIP-0010 avec HMAC-SHA512. PBKDF2 utilise CommonCrypto. [S3]'),
    ('Dérivation Iroha héritée', '<b>scrypt</b>, N=16384, r=8, p=1, sortie de 32 octets ; mnémonique normalisée NFKD et sel construit selon SORA|iroha keypair|password. Ces paramètres sont distincts de ceux des sauvegardes. [S4]'),
])
heading('Gestion des secrets')
add("Les clés privées servent à la signature locale des opérations autorisées par l'utilisateur. Les comptes et secrets conservés par les versions antérieures sont pris en compte par les mécanismes de migration. L'ajout de réseaux nécessite des dérivations adaptées aux comptes et aux réseaux concernés ; l'inventaire ci-dessus décrit ces mécanismes, sans attester des résultats de chaque migration individuelle.")
add("Les sources [S1] à [S6] sont identifiées en page 4. Les primitives de signature et celles du dispositif de qualification sont précisées séparément en page 3.", 'SmallFR')

story.append(PageBreak())
add('ANNEXE TECHNIQUE  /  AUTHENTICITÉ ET INTÉGRITÉ', 'KickerFR')
add('Signatures et fonctions associées', 'TitleFR')
rows([
    ('Signatures des comptes', '<b>sr25519 / Schnorrkel</b> sur Ristretto255, <b>Ed25519</b> sur Edwards25519, et <b>ECDSA / secp256k1</b>, selon le compte et le réseau. Le chemin ECDSA examiné préhache avec BLAKE2b-256. Bibliothèques IrohaCrypto et primitives publiques intégrées. [S5]'),
    ('Iroha historique', 'Variante publiée <b>Iroha Ed25519 avec SHA3</b>, issue de l\'implémentation publique Hyperledger Iroha. Elle est distinguée d\'Ed25519 tel que spécifié avec SHA-512 dans RFC 8032. Le message de migration observé est préhaché avec SHA3-256. [S4, S5]'),
    ('Authentification des sessions', '<b>Ed25519</b> signe et vérifie les approbations et messages examinés dans les sessions IrohaConnect. Ces signatures sont distinctes du chiffrement ChaCha20-Poly1305 des messages de session. [S2]'),
    ('Hachage et MAC', '<b>BLAKE2b</b> (128, 256 et 512 bits), <b>Keccak-256</b>, <b>SHA3-256 / SHA3-512</b>, <b>SHA-256 / SHA-512</b>, et <b>HMAC-SHA256 / HMAC-SHA512</b>, selon les formats, dérivations et protocoles concernés. [S2-S6]'),
])
heading('Dispositif de qualification des migrations')
add("Le code comprend aussi un dispositif destiné aux preuves de qualification autorisées. Il utilise <b>AES-256-GCM</b> (CryptoKit) pour sceller des états de référence, <b>HMAC-SHA256</b> pour authentifier leur état et la vérification <b>ECDSA P-256</b> (CryptoKit) pour les autorisations signées. Ces fonctions sont identifiées comme des mécanismes de qualification ; elles ne sont pas décrites comme le format de sauvegarde courant ou la signature des transactions du portefeuille. [S6]")
heading("Portée de l'examen")
add("L'inventaire repose sur la lecture du code source correspondant au build téléversé. Il distingue confidentialité, signature, dérivation de clés et qualification. Il ne prétend ni remplacer un contrôle administratif ni démontrer la date d'introduction de chaque primitive. Aucune nouvelle primitive cryptographique n'est créée par ce document.")
add("La mention de primitives publiques décrit leur conception et leur disponibilité ; elle ne prétend pas que chaque protocole ou variante citée possède la même normalisation internationale.", 'SmallFR')

story.append(PageBreak())
add('TRAÇABILITÉ  /  SOURCE DU BUILD ET RÉFÉRENCES', 'KickerFR')
add('Éléments de vérification', 'TitleFR')
add(f"Référentiel : sora-xor/sora-ios<br/>Révision complète : <b>{COMMIT}</b><br/>Build iOS : <b>3.8.7 (2026090601)</b><br/>Identifiant du build Apple : 7dac8be4-bdc2-4d05-a5ec-3926a9a51ee2", 'BodyFR')
heading('Références du code source')
references = [
    ('S1 - Sauvegardes', 'SoraPassport/Common/Crypto/KeystoreExportWrapper.swift, à partir de la ligne 108 ; ScryptParameters.swift dans le même dossier.'),
    ('S2 - IrohaConnect', 'SoraPassport/Common/IrohaConnectProtocol.swift, lignes 1003-1084 ; SoraPassport/Common/IrohaConnectSession.swift, lignes 287-324 et 386-400.'),
    ('S3 - Dérivation Nexus', 'SoraPassport/Common/Model/WalletNetworkModel.swift, à partir de la ligne 3610.'),
    ('S4 - Compatibilité Iroha', 'SoraPassport/Common/Crypto/IRKeypairFacade.swift, lignes 57-75 ; SoraPassport/ModulesRedesign/Migration/MigrationService.swift, à partir de la ligne 666. Implémentations intégrées IRScryptKeyDeriviation.m et IRSeedCreator.m dans VendorPackages/shared-features-spm.'),
    ('S5 - Signatures et utilitaires', 'SoraPassport/Common/Crypto/SigningWrapperProtocol.swift, à partir de la ligne 43 ; SigningWrapper.swift et IRSigningDecorator.swift dans le même dossier. Sources IrohaCrypto et SSFCrypto dans VendorPackages/shared-features-spm/Sources.'),
    ('S6 - Qualification', 'SoraPassport/Common/MigrationEvidence/RetainedMigrationEvidenceHarness.swift, lignes 1188-1196 (autorisation P-256) et à partir de la ligne 1865 (chiffrement des états de référence).'),
]
for label, detail in references:
    add(f'<b>{escape(label)}</b><br/>{escape(detail)}', 'SmallFR')
heading('Références administratives')
for label, url in [
    ("Apple - Export compliance documentation for encryption", 'https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption'),
    ("Apple - Determine and upload app encryption documentation", 'https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation'),
    ("ANSSI - Contrôle des moyens de cryptologie et formulaires", 'https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-reglementaire-cryptographie-formulaires/'),
]:
    add(f'<link href="{escape(url)}" color="#173448"><u>{escape(label)}</u></link>', 'SmallFR')
add("Références consultées le 6 septembre 2026. Les liens administratifs précisent les procédures applicables ; leur citation n'implique aucune approbation de ce dossier.", 'SmallFR')
heading('English reviewer note')
add("This is the developer's technical cryptography declaration for SORA Wallet 3.8.7 (2026090601), intended for distribution in France. It identifies public primitives, operating-system services and bundled implementations. It is <b>not an ANSSI-issued approval certificate</b> and does not claim a regulatory filing number or approval.", 'SmallFR')

def page_decoration(canvas, doc):
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(RULE)
    canvas.setLineWidth(.5)
    canvas.line(52, 45, width-52, 45)
    canvas.setFont('Helvetica', 7.5)
    canvas.setFillColor(GRAY)
    canvas.drawString(52, 32, 'SORA Wallet 3.8.7 (2026090601) | Déclaration technique de l\'éditeur')
    canvas.drawRightString(width-52, 32, f'{doc.page} / 4')
    canvas.restoreState()

OUT.parent.mkdir(parents=True, exist_ok=True)
doc = SimpleDocTemplate(str(OUT), pagesize=A4, rightMargin=52, leftMargin=52, topMargin=48, bottomMargin=60,
    title='SORA Wallet - Déclaration technique de cryptologie - France - 2026090601',
    author='Soramitsu Co., Ltd.', subject='Developer technical declaration for App Store Connect review',
    creator='ReportLab')
doc.build(story, onFirstPage=page_decoration, onLaterPages=page_decoration)
reader = PdfReader(str(OUT))
assert len(reader.pages) == 4, f'Unexpected page count: {len(reader.pages)}'
extracted = '\n\n'.join(page.extract_text() or '' for page in reader.pages)
for text in ['2026090601', 'X25519', 'ChaCha20-Poly1305', 'XSalsa20-Poly1305', 'P-256', COMMIT]:
    assert text in extracted, text
assert '2026081101' not in extracted
(TMP / 'declaration-extracted.txt').write_text(extracted)
print(str(OUT))
print(f'{len(reader.pages)} pages; {OUT.stat().st_size} bytes; text validation passed')
