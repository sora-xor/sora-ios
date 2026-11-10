// Differential harness for the sr25519 / ed25519 / blake2 C APIs used by IrohaCrypto.
// Compiled once against the old prebuilt archives and once against the in-repo
// sources; deterministic outputs must match byte for byte, randomized sr25519
// signatures are cross-verified.
//
//   harness gen <count>          deterministic vectors on stdout
//   harness verify <file>        reads "pub msg sig" hex lines, prints 1/0 per line
//   harness fromed <count>       from_ed25519_bytes on arbitrary 64-byte inputs
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sr25519.h"
#include "ed25519.h"
#include "ed25519_sha2.h"
#include "blake2b.h"
#include "blake2s.h"

static uint64_t state = 0x5eed5eed12345678ULL;
static uint64_t next64(void) {
    uint64_t z = (state += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}
static void fill(uint8_t *p, size_t n) {
    for (size_t i = 0; i < n; i++) p[i] = (uint8_t)next64();
}
static void hex(const char *tag, int i, const uint8_t *p, size_t n) {
    printf("%s %d ", tag, i);
    for (size_t k = 0; k < n; k++) printf("%02x", p[k]);
    printf("\n");
}
static void hexs(const uint8_t *p, size_t n) {
    for (size_t k = 0; k < n; k++) printf("%02x", p[k]);
}
static int unhex(const char *s, uint8_t *out, size_t max) {
    size_t n = strlen(s);
    if (n % 2 || n / 2 > max) return -1;
    for (size_t i = 0; i < n / 2; i++) {
        unsigned v;
        if (sscanf(s + 2 * i, "%2x", &v) != 1) return -1;
        out[i] = (uint8_t)v;
    }
    return (int)(n / 2);
}

static void gen(int count) {
    for (int i = 0; i < count; i++) {
        uint8_t seed[32], cc[32], kp[96], hard[96], soft[96], pubsoft[32], ed[64], back[64];
        fill(seed, 32);
        fill(cc, 32);
        sr25519_keypair_from_seed(kp, seed);
        hex("KP", i, kp, 96);
        sr25519_derive_keypair_hard(hard, kp, cc);
        hex("HARD", i, hard, 96);
        sr25519_derive_keypair_soft(soft, kp, cc);
        hex("SOFTKEY", i, soft, 32);
        hex("SOFTPUB", i, soft + 64, 32);
        sr25519_derive_public_soft(pubsoft, kp + 64, cc);
        hex("PUBSOFT", i, pubsoft, 32);
        // chained derivations: //hard/soft and /soft//hard
        uint8_t hs[96], sh[96];
        sr25519_derive_keypair_soft(hs, hard, cc);
        hex("HARDSOFTKEY", i, hs, 32);
        hex("HARDSOFTPUB", i, hs + 64, 32);
        sr25519_derive_keypair_hard(sh, soft, cc);
        hex("SOFTHARD", i, sh, 96);
        sr25519_to_ed25519_bytes(ed, kp);
        hex("TOED", i, ed, 64);
        sr25519_from_ed25519_bytes(back, ed);
        hex("FROMED", i, back, 64);

        // signatures: randomized, emitted for cross-verification
        size_t mlen = (size_t)(next64() % 300);
        uint8_t msg[300];
        fill(msg, mlen);
        uint8_t sig[64];
        sr25519_sign(sig, kp + 64, kp, msg, mlen);
        bool ok = sr25519_verify(sig, msg, mlen, kp + 64);
        uint8_t bad[64];
        memcpy(bad, sig, 64);
        bad[next64() % 64] ^= (uint8_t)(1u << (next64() % 8));
        bool badok = sr25519_verify(bad, msg, mlen, kp + 64);
        printf("SELFVERIFY %d %d %d\n", i, ok ? 1 : 0, badok ? 1 : 0);
        printf("SIG %d ", i);
        hexs(kp + 64, 32);
        printf(" ");
        if (mlen) hexs(msg, mlen); else printf("-");
        printf(" ");
        hexs(sig, 64);
        printf("\n");
        // signing with a soft-derived key (random nonce part) must verify too
        uint8_t sig2[64];
        sr25519_sign(sig2, soft + 64, soft, msg, mlen);
        printf("SOFTSIGVERIFY %d %d\n", i, sr25519_verify(sig2, msg, mlen, soft + 64) ? 1 : 0);

        // ed25519 (SHA-512, orlp API)
        uint8_t epub[32], epriv[64], esig[64], dpub[32];
        ed25519_sha2_create_keypair(epub, epriv, seed);
        hex("EDPUB", i, epub, 32);
        hex("EDPRIV", i, epriv, 64);
        ed25519_sha2_sign(esig, msg, mlen, epub, epriv);
        hex("EDSIG", i, esig, 64);
        int ev = ed25519_sha2_verify(esig, msg, mlen, epub);
        esig[next64() % 64] ^= 1;
        int evbad = ed25519_sha2_verify(esig, msg, mlen, epub);
        printf("EDVERIFY %d %d %d\n", i, ev, evbad);
        uint8_t epriv2[64];
        memcpy(epriv2, epriv, 64);
        ed25519_sha2_derive_keypair(dpub, epriv2);
        hex("EDDERIVEPUB", i, dpub, 32);
        hex("EDDERIVEPRIV", i, epriv2, 64);
        uint8_t shared[32];
        ed25519_sha2_key_exchange(shared, epub, epriv);
        hex("EDKEX", i, shared, 32);

        // Iroha ed25519 (SHA3-512)
        private_key_t isk;
        public_key_t ipk;
        signature_t isig;
        memcpy(isk.data, seed, 32);
        ed25519_derive_public_key(&isk, &ipk);
        hex("IRPUB", i, ipk.data, 32);
        ed25519_sign(&isig, msg, mlen, &ipk, &isk);
        hex("IRSIG", i, isig.data, 64);
        int iv = ed25519_verify(&isig, msg, mlen, &ipk);
        isig.data[next64() % 64] ^= 0x10;
        int ivbad = ed25519_verify(&isig, msg, mlen, &ipk);
        printf("IRVERIFY %d %d %d\n", i, iv, ivbad);

        // blake2b / blake2s, one-shot and streamed
        size_t outb = 1 + (size_t)(next64() % 64), outs = 1 + (size_t)(next64() % 32);
        size_t keylen = (i % 3 == 0) ? (size_t)(next64() % 65) : 0;
        uint8_t key[64], hb[64], hs2[32];
        fill(key, keylen);
        blake2b(hb, outb, keylen ? key : NULL, keylen, msg, mlen);
        hex("B2B", i, hb, outb);
        blake2s(hs2, outs, (keylen && keylen <= 32) ? key : NULL, keylen <= 32 ? keylen : 0, msg, mlen);
        hex("B2S", i, hs2, outs);
        blake2b_ctx bctx;
        blake2b_init(&bctx, 32, NULL, 0);
        size_t half = mlen / 3;
        blake2b_update(&bctx, msg, half);
        blake2b_update(&bctx, msg + half, mlen - half);
        blake2b_final(&bctx, hb);
        hex("B2BSTREAM", i, hb, 32);
    }
    // Iroha random keypair: valid and self-consistent
    for (int i = 0; i < 20; i++) {
        private_key_t sk;
        public_key_t pk, pk2;
        int r = ed25519_create_keypair(&sk, &pk);
        ed25519_derive_public_key(&sk, &pk2);
        printf("IRCREATE %d %d %d\n", i, r != 0, memcmp(pk.data, pk2.data, 32) == 0);
    }
}

static void verify_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) { perror(path); exit(2); }
    char line[4096];
    while (fgets(line, sizeof line, f)) {
        char tag[16], pubh[128], msgh[1024], sigh[256];
        int idx;
        if (sscanf(line, "%15s %d %127s %1023s %255s", tag, &idx, pubh, msgh, sigh) != 5) continue;
        if (strcmp(tag, "SIG")) continue;
        uint8_t pub[32], msg[512], sig[64];
        int ml = strcmp(msgh, "-") ? unhex(msgh, msg, sizeof msg) : 0;
        if (unhex(pubh, pub, 32) != 32 || ml < 0 || unhex(sigh, sig, 64) != 64) { printf("PARSE %d\n", idx); continue; }
        printf("XVERIFY %d %d\n", idx, sr25519_verify(sig, msg, (unsigned long)ml, pub) ? 1 : 0);
    }
    fclose(f);
}

static void fromed(int count) {
    for (int i = 0; i < count; i++) {
        uint8_t in[64], out[64];
        fill(in, 64);
        if (i % 4 == 1) memset(in, 0xff, 32);
        if (i % 4 == 2) memset(in, 0, 32);
        sr25519_from_ed25519_bytes(out, in);
        hex("FROMEDRAW", i, out, 64);
    }
}

int main(int argc, char **argv) {
    if (argc >= 3 && !strcmp(argv[1], "gen")) gen(atoi(argv[2]));
    else if (argc >= 3 && !strcmp(argv[1], "verify")) verify_file(argv[2]);
    else if (argc >= 3 && !strcmp(argv[1], "fromed")) fromed(atoi(argv[2]));
    else { fprintf(stderr, "usage\n"); return 2; }
    return 0;
}
