use schnorrkel::{PublicKey, SecretKey};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;

const SECRET_KEY_LENGTH: usize = 64;
const PUBLIC_KEY_LENGTH: usize = 32;

/// Validates a serialized sr25519 secret/public pair without allowing a Rust
/// panic to cross the C ABI boundary.
///
/// The caller must keep both non-null buffers alive for the duration of this
/// call. Invalid lengths, malformed encodings, mismatched key pairs, and any
/// internal panic all return `false`.
#[no_mangle]
pub unsafe extern "C" fn sora_sr25519_keypair_is_valid(
    secret_ptr: *const u8,
    secret_len: usize,
    public_ptr: *const u8,
    public_len: usize,
) -> bool {
    if secret_ptr.is_null()
        || public_ptr.is_null()
        || secret_len != SECRET_KEY_LENGTH
        || public_len != PUBLIC_KEY_LENGTH
    {
        return false;
    }

    catch_unwind(AssertUnwindSafe(|| {
        let secret_bytes = slice::from_raw_parts(secret_ptr, secret_len);
        let public_bytes = slice::from_raw_parts(public_ptr, public_len);

        let secret = match SecretKey::from_bytes(secret_bytes) {
            Ok(value) => value,
            Err(_) => return false,
        };
        let public = match PublicKey::from_bytes(public_bytes) {
            Ok(value) => value,
            Err(_) => return false,
        };

        secret.to_public() == public
    }))
    .unwrap_or(false)
}

/// Release-validation hook proving a panic remains contained inside this Rust
/// runtime instead of crossing the Objective-C ABI boundary.
#[no_mangle]
pub extern "C" fn sora_sr25519_validator_contains_forced_panic() -> bool {
    catch_unwind(AssertUnwindSafe(|| panic!("forced validator containment test"))).is_err()
}

#[cfg(test)]
mod tests {
    use super::*;
    use schnorrkel::{ExpansionMode, MiniSecretKey};

    fn validate(secret: &[u8], public: &[u8]) -> bool {
        unsafe {
            sora_sr25519_keypair_is_valid(
                secret.as_ptr(),
                secret.len(),
                public.as_ptr(),
                public.len(),
            )
        }
    }

    #[test]
    fn accepts_matching_keypair() {
        let seed = [7_u8; 32];
        let secret = MiniSecretKey::from_bytes(&seed)
            .unwrap()
            .expand(ExpansionMode::Ed25519);
        let public = secret.to_public();

        assert!(validate(&secret.to_bytes(), &public.to_bytes()));
    }

    #[test]
    fn rejects_malformed_or_mismatched_material() {
        let seed = [7_u8; 32];
        let secret = MiniSecretKey::from_bytes(&seed)
            .unwrap()
            .expand(ExpansionMode::Ed25519);
        let other = MiniSecretKey::from_bytes(&[8_u8; 32])
            .unwrap()
            .expand_to_public(ExpansionMode::Ed25519);

        assert!(!validate(&secret.to_bytes(), &other.to_bytes()));
        assert!(!validate(&[0xff; 64], &other.to_bytes()));
        assert!(!validate(&secret.to_bytes(), &[0xff; 32]));
        assert!(!validate(&secret.to_bytes()[..63], &other.to_bytes()));
    }

    #[test]
    fn contains_panics_before_the_ffi_boundary() {
        assert!(sora_sr25519_validator_contains_forced_panic());
    }
}
