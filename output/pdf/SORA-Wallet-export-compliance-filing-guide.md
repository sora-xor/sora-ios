# SORA Wallet 3.8.7 export-compliance filing guide

Build: `3.8.7 (2026081101)`  
Source revision: `d657f9ccc55ba1f9558c474229bc470375a71bfd`  
Apple delivery ID: `fced1501-b378-44ae-ac95-8a38d8bfac70`

## App Store Connect answers

Use these answers for this binary:

1. The app uses encryption: **Yes**.
2. Encryption is limited to Apple's operating system: **No**.
3. Algorithm type: **Standard encryption algorithms instead of, or in addition to, Apple's operating system**.
4. Do **not** select proprietary/non-standard algorithms and do **not** select “both.” The unusual app-bundled variants are publicly published; no proprietary or unpublished confidentiality algorithm was found. This answer relies on Apple/BIS's published definition of non-standard cryptography.
5. The app will be distributed in France: **Yes**.
6. Do not claim the banking-app exemption without written ANSSI or export-counsel confirmation. A non-custodial wallet exposes key, seed, and signing capabilities to the user.

This path requires a French encryption declaration. It does not require a CCATS merely because a publicly published algorithm lacks formal standards-body adoption, subject to Soramitsu's export-control owner confirming the classification.

## Files prepared

- `SORA-Wallet-ANSSI-Annex-I-draft.pdf`: official ANSSI XFA form with its datasets prefilled. It is unsigned and must be opened in Adobe Acrobat Reader; Preview and browser PDF viewers cannot render the dynamic form.
- `SORA-Wallet-cryptography-technical-dossier.pdf`: technical inventory and filing annex for the exact uploaded binary.

## Required human and corporate inputs

1. Open the Annex I draft in Adobe Acrobat Reader and verify every field.
2. Add the Japanese corporate-registration identifier if ANSSI expects one in place of SIRET.
3. Confirm the commercialization date and grand-public classification request.
4. Makoto Takemiya, or another authorized representative, must add the date and signature.
5. Obtain a Japanese company-registry extract or equivalent issued within the last three months.
6. Save the completed editable PDF and create a signed/scanned PDF copy. Do not overwrite the editable original.

## ANSSI filing

Send to `controle@ssi.gouv.fr` with subject:

`[formalités] SORA - SORA Wallet: Polkaswap`

Attach:

- the completed editable Annex I form;
- the signed/scanned Annex I copy;
- the technical dossier;
- the recent Japanese registry extract;
- any available product overview, commercial brochure, technical documentation, and user guide.

Keep ANSSI's acknowledgment and the eventual `Attestation de déclaration`.

## Apple upload

In App Store Connect, upload a truthful French declaration package. The strongest package is the signed Annex I form plus ANSSI filing acknowledgment, followed by the ANSSI attestation when issued. Never upload the unsigned draft as an ANSSI approval.

After Apple approves the documentation, attach the approval to build `2026081101`, add an internal TestFlight group, and add Apple's export-compliance code to the next build configuration.

## Important build note

Build `2026081101` was uploaded from revision `d657f9cc`. It does not include the five uncommitted changes currently present in the local working tree on 14 August 2026. Those changes require a new committed revision, new build number, fresh archive, and upload.
