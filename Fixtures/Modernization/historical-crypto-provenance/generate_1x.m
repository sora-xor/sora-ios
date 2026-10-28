// Public synthetic fixtures. Compile against unmodified IrohaCrypto 0.2.6.
#import <Foundation/Foundation.h>
#import "IRMnemonicCreator.h"
#import "IRSeedCreator.h"
#import "IRCryptoKeyFactory.h"
#import "IRSignatureCreator.h"
#import "IRSignatureVerifier.h"
#import "NSData+Hex.h"

int main(void) { @autoreleasepool {
    NSData *challenge = [@"SORA historical fixture audit 2026-10-12" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *vectors = [NSMutableArray array];
    IRBIP39MnemonicCreator *mnemonics = [IRBIP39MnemonicCreator defaultCreator];
    IRBIP39ScryptSeedCreator *seeds = [IRBIP39ScryptSeedCreator defaultCreator];
    IREd25519KeyFactory *keys = [IREd25519KeyFactory new];
    IREd25519Sha512Verifier *verifier = [IREd25519Sha512Verifier new];
    for (NSString *password in @[@"", @"public-fixture-password"]) {
        // 1.x app generated 160 bits / 15 words; this deliberately uses zeros.
        NSError *error = nil;
        NSData *entropy = [NSMutableData dataWithLength:20];
        id<IRMnemonicProtocol> mnemonic = [mnemonics mnemonicFromEntropy:entropy error:&error];
        NSCAssert(mnemonic && !error, @"Mnemonic failed: %@", error);
        NSData *secret = [seeds deriveSeedFromMnemonicPhrase:[mnemonic toString] password:password
                                                    project:@"SORA" purpose:@"iroha keypair" length:32 error:&error];
        NSCAssert(secret && !error, @"Scrypt failed: %@", error);
        id<IRCryptoKeypairProtocol> pair = [keys deriveFromPrivateKey:[[IREd25519PrivateKey alloc] initWithRawData:secret]];
        IREd25519Sha512Signer *signer = [[IREd25519Sha512Signer alloc] initWithPrivateKey:[pair privateKey]];
        id<IRSignatureProtocol> signature = [signer sign:challenge];
        BOOL verified = [verifier verify:signature forOriginalData:challenge usingPublicKey:[pair publicKey]];
        NSCAssert(verified, @"Historical signature failed verification");
        NSData *restored = [seeds deriveSeedFromMnemonicPhrase:[mnemonic toString] password:password
                                                      project:@"SORA" purpose:@"iroha keypair" length:32 error:&error];
        NSCAssert([secret isEqualToData:restored], @"Phrase round trip changed secret");
        [vectors addObject:@{@"id": password.length ? @"ios-1x-15words-password" : @"ios-1x-15words",
                             @"family": @"IrohaCrypto-0.2.6", @"scheme": @"legacy-iroha-ed25519",
                             @"entropyHex": [entropy toHexString], @"phrase": [mnemonic toString], @"password": password,
                             @"project": @"SORA", @"purpose": @"iroha keypair", @"secretKeyHex": [secret toHexString],
                             @"publicKeyHex": [[[pair publicKey] rawData] toHexString],
                             @"challengeHex": [challenge toHexString], @"signatureHex": [[signature rawData] toHexString],
                             @"signatureVerified": @(verified), @"phraseExportRoundTrip": @YES,
                             @"ss58Address": [NSNull null],
                             @"notes": @"Legacy Iroha identity, not a Substrate identity; new-chain migration must be tested separately."}];
    }
    // An unchanged upstream test case checks that the historical KDF harness is wired correctly.
    NSError *error = nil;
    NSData *testSeed = [seeds deriveSeedFromMnemonicPhrase:@"ice just spike final seminar crater shadow ensure fame rival flip put virtual picnic galaxy"
                                                  password:@"testPassword" project:@"testProject" purpose:@"test purpose"
                                                    length:32 error:&error];
    NSCAssert([[testSeed toHexString] isEqual:@"2a58dee913307de72e6cf7ea851ab094a48be772f7177b846df19098825d1d11"],
              @"Upstream KDF test vector failed");
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"upstreamKDFKnownAnswerPassed": @YES, @"vectors": vectors}
                                                  options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
    NSCAssert(json && !error, @"JSON failed");
    fwrite(json.bytes, 1, json.length, stdout);
    fputc('\n', stdout);
} return 0; }
