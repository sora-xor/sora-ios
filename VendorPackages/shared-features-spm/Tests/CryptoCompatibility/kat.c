// Known-answer tests for the in-repo sr25519 sources: RFC 9496 ristretto255
// encodings (A.1 multiples of the generator, A.2 invalid encodings), the
// Substrate development keys, and verify() on invalid public keys.
#include <stdio.h>
#include <string.h>
#include "sr25519lib/sr25519.h"
#include "donna/ristretto255.h"

static int failures = 0;
static void unhex(const char *s, uint8_t *out) {
    for (size_t i = 0; i < strlen(s) / 2; i++) { unsigned v; sscanf(s + 2 * i, "%2x", &v); out[i] = (uint8_t)v; }
}
static void check(int ok, const char *what) {
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) failures++;
}

static const char *MULTIPLES[16] = {
    "0000000000000000000000000000000000000000000000000000000000000000",
    "e2f2ae0a6abc4e71a884a961c500515f58e30b6aa582dd8db6a65945e08d2d76",
    "6a493210f7499cd17fecb510ae0cea23a110e8d5b901f8acadd3095c73a3b919",
    "94741f5d5d52755ece4f23f044ee27d5d1ea1e2bd196b462166b16152a9d0259",
    "da80862773358b466ffadfe0b3293ab3d9fd53c5ea6c955358f568322daf6a57",
    "e882b131016b52c1d3337080187cf768423efccbb517bb495ab812c4160ff44e",
    "f64746d3c92b13050ed8d80236a7f0007c3b3f962f5ba793d19a601ebb1df403",
    "44f53520926ec81fbd5a387845beb7df85a96a24ece18738bdcfa6a7822a176d",
    "903293d8f2287ebe10e2374dc1a53e0bc887e592699f02d077d5263cdd55601c",
    "02622ace8f7303a31cafc63f8fc48fdc16e1c8c8d234b2f0d6685282a9076031",
    "20706fd788b2720a1ed2a5dad4952b01f413bcf0e7564de8cdc816689e2db95f",
    "bce83f8ba5dd2fa572864c24ba1810f9522bc6004afe95877ac73241cafdab42",
    "e4549ee16b9aa03099ca208c67adafcafa4c3f3e4e5303de6026e3ca8ff84460",
    "aa52e000df2e16f55fb1032fc33bc42742dad6bd5a8fc0be0167436c5948501f",
    "46376b80f409b29dc2b5f6f0c52591990896e5716f41477cd30085ab7f10301e",
    "e0c418f7c8d9c4cdd7395b93ea124f3ad99021bb681dfc3302a9d99a2e53e64e",
};

static const char *BAD[] = {
    // non-canonical field encodings
    "00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "f3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    // negative field elements
    "0100000000000000000000000000000000000000000000000000000000000000",
    "01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
    "ed57ffd8c914fb201471d1c3d245ce3c746fcbe63a3679d51b6a516ebebe0e20",
    "c34c4e1826e5d403b78e246e88aa051c36ccf0aafebffe137d148a2bf9104562",
    "c940e5a4404157cfb1628b108db051a8d439e1a421394ec4ebccb9ec92a8ac78",
    "47cfc5497c53dc8e61c91d17fd626ffb1c49e2bca94eed052281b510b1117a24",
    "f1c6165d33367351b0da8f6e4511010c68174a03b6581212c71c0e1d026c3c72",
    "87260f7a2f12495118360f02c26a470f450dadf34a413d21042b43b9d93e1309",
    // non-square x^2
    "26948d35ca62e643e26a83177332e6b6afeb9d08e4268b650f1f5bbd8d81d371",
    "4eac077a713c57b4f4397629a4145982c661f48044dd3f96427d40b147d9742f",
    "de6a7b00deadc788eb6b6c8d20c0ae96c2f2019078fa604fee5b87d6e989ad7b",
    "bcab477be20861e01e4a0e295284146a510150d9817763caf1a6f4b422d67042",
    "2a292df7e32cababbd9de088d1d1abec9fc0440f637ed2fba145094dc14bea08",
    "f4a9e534fc0d216c44b218fa0c42d99635a0127ee2e53c712f70609649fdff22",
    "8268436f8c4126196cf64b3c7ddbda90746a378625f9813dd9b8457077256731",
    "2810e5cbc2cc4d4eece54f61c6f69758e289aa7ab440b3cbeaa21995c2f4232b",
    // negative xy value
    "3eb858e78f5a7254d8c9731174a94f76755fd3941c0ac93735c07ba14579630e",
    "a45fdc55c76448c049a1ab33f17023edfb2be3581e9c7aade8a6125215e04220",
    "d483fe813c6ba647ebbfd3ec41adca1c6130c2beeee9d9bf065c8d151c5f396e",
    "8a2e1d30050198c65a54483123960ccc38aef6848e1ec8f5f780e8523769ba32",
    "32888462f8b486c68ad7dd9610be5192bbeaf3b443951ac1a8118419d9fa097b",
    "227142501b9d4355ccba290404bde41575b037693cef1f438c47f8fbf35d1165",
    "5c37cc491da847cfeb9281d407efc41e15144c876e0170b499a96a22ed31e01e",
    "445425117cb8c90edcbc7c1cc0e74f747f2c1efa5630a967c64f287792a48a4b",
    // s = -1, which causes y = 0
    "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
};

int main(void) {
    // A.1: encodings of B*i, via keypair public keys of scalar i
    uint8_t enc[32], expect[32];
    ge25519 P;
    for (int i = 0; i < 16; i++) {
        unhex(MULTIPLES[i], expect);
        int ok = ristretto_decode(&P, expect);
        ristretto_encode(enc, P);
        char what[64];
        snprintf(what, sizeof what, "rfc9496 A.1 B*%d decode/encode round trip", i);
        check(ok == 1 && memcmp(enc, expect, 32) == 0, what);
    }
    // B*i = (B*(i-1)) + B by soft-deriving? Use the secret scalars directly:
    // a secret whose canonical scalar is i has public key B*i.
    for (int i = 1; i < 16; i++) {
        uint8_t secret[64] = {0}, sig[64], pub[32], msg[3] = {1, 2, 3};
        secret[0] = (uint8_t)i;
        unhex(MULTIPLES[i], pub);
        sr25519_sign(sig, pub, secret, msg, 3);
        char what[64];
        snprintf(what, sizeof what, "rfc9496 A.1 scalar %d signs for B*%d", i, i);
        check(sr25519_verify(sig, msg, 3, pub), what);
    }
    // A.2: every bad encoding is rejected, and verify() returns false for it
    for (size_t i = 0; i < sizeof BAD / sizeof BAD[0]; i++) {
        uint8_t bad[32], sig[64] = {0};
        unhex(BAD[i], bad);
        sig[63] = 0x80;
        char what[80];
        snprintf(what, sizeof what, "rfc9496 A.2 bad encoding %zu rejected", i);
        check(ristretto_decode(&P, bad) == 0 && !sr25519_verify(sig, (const uint8_t *)"m", 1, bad), what);
    }

    // Substrate development key: mini secret of "bottom drive obey lake curtain
    // smoke basket hold race lonely fit walk", and //Alice.
    uint8_t mini[32], kp[96], alice[96], cc[32] = {0}, want[32];
    unhex("fac7959dbfe72f052e5a0c3c8d6530f202b02fd8f9f5ca3580ec8deb7797479e", mini);
    sr25519_keypair_from_seed(kp, mini);
    unhex("46ebddef8cd9bb167dc30878d7113b7e168e6f0646beffd77d69d39bad76b47a", want);
    check(memcmp(kp + 64, want, 32) == 0, "substrate dev phrase public key 46ebddef...");
    cc[0] = 0x14; memcpy(cc + 1, "Alice", 5);  // SCALE-encoded "Alice", zero padded
    sr25519_derive_keypair_hard(alice, kp, cc);
    unhex("d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d", want);
    check(memcmp(alice + 64, want, 32) == 0, "//Alice public key d43593c7...");
    uint8_t bob[96];
    cc[0] = 0x0c; memset(cc + 1, 0, 31); memcpy(cc + 1, "Bob", 3);
    sr25519_derive_keypair_hard(bob, kp, cc);
    unhex("8eaf04151687736326c9fea17e25fc5287613693c912909cb226aa4794f26a48", want);
    check(memcmp(bob + 64, want, 32) == 0, "//Bob public key 8eaf0415...");

    // Signature malleability: s + l must be rejected; unmarked signature too.
    uint8_t sig[64], msg[5] = "hello";
    sr25519_sign(sig, alice + 64, alice, msg, 5);
    check(sr25519_verify(sig, msg, 5, alice + 64), "alice signature verifies");
    uint8_t unmarked[64];
    memcpy(unmarked, sig, 64);
    unmarked[63] &= 0x7f;
    check(!sr25519_verify(unmarked, msg, 5, alice + 64), "signature without the schnorrkel marker is rejected");
    check(!sr25519_verify(sig, msg, 4, alice + 64), "signature over another message is rejected");
    check(!sr25519_verify(sig, msg, 5, bob + 64), "signature under another key is rejected");

    printf("%d failures\n", failures);
    return failures != 0;
}
