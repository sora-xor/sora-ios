use schnorrkel::{PublicKey, SecretKey};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;

const SECRET_KEY_LENGTH: usize = 64;
const PUBLIC_KEY_LENGTH: usize = 32;

unsafe fn convert_ed25519_secret_with<F>(
    ed25519_ptr: *const u8,
    ed25519_len: usize,
    output_ptr: *mut u8,
    output_len: usize,
    converter: F,
) -> bool
where
    F: FnOnce(&[u8]) -> Option<[u8; SECRET_KEY_LENGTH]>,
{
    if ed25519_ptr.is_null()
        || output_ptr.is_null()
        || ed25519_len != SECRET_KEY_LENGTH
        || output_len != SECRET_KEY_LENGTH
    {
        return false;
    }

    catch_unwind(AssertUnwindSafe(|| {
        // Copy before borrowing the output so callers may safely use the same
        // buffer for input and output.
        let mut ed25519_bytes = [0_u8; SECRET_KEY_LENGTH];
        ed25519_bytes.copy_from_slice(slice::from_raw_parts(ed25519_ptr, ed25519_len));

        let output_bytes = slice::from_raw_parts_mut(output_ptr, output_len);
        for byte in output_bytes.iter_mut() {
            *byte = 0;
        }

        let converted = match converter(&ed25519_bytes) {
            Some(value) => value,
            None => return false,
        };

        output_bytes.copy_from_slice(&converted);
        true
    }))
    .unwrap_or(false)
}

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

/// Converts a 64-byte Ed25519-expanded secret from a Substrate JSON keystore
/// into schnorrkel's canonical 64-byte sr25519 secret representation.
///
/// The caller must keep both buffers alive for the duration of this call.
/// Invalid pointers or lengths, malformed input, and any internal panic return
/// `false`. For valid buffers, a failed conversion clears the output.
#[no_mangle]
pub unsafe extern "C" fn sora_sr25519_secret_from_ed25519(
    ed25519_ptr: *const u8,
    ed25519_len: usize,
    output_ptr: *mut u8,
    output_len: usize,
) -> bool {
    convert_ed25519_secret_with(
        ed25519_ptr,
        ed25519_len,
        output_ptr,
        output_len,
        |ed25519_bytes| {
            SecretKey::from_ed25519_bytes(ed25519_bytes)
                .ok()
                .map(|secret| secret.to_bytes())
        },
    )
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

    fn convert(ed25519_secret: &[u8], output: &mut [u8]) -> bool {
        unsafe {
            sora_sr25519_secret_from_ed25519(
                ed25519_secret.as_ptr(),
                ed25519_secret.len(),
                output.as_mut_ptr(),
                output.len(),
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
    fn converts_ed25519_expanded_secret_to_canonical_sr25519() {
        let secret = MiniSecretKey::from_bytes(&[7_u8; 32])
            .unwrap()
            .expand(ExpansionMode::Ed25519);
        let public = secret.to_public();
        let mut converted = [0_u8; SECRET_KEY_LENGTH];

        assert!(convert(&secret.to_ed25519_bytes(), &mut converted));
        assert_eq!(&converted[..], &secret.to_bytes()[..]);
        assert!(validate(&converted, &public.to_bytes()));
    }

    #[test]
    fn conversion_rejects_invalid_buffers() {
        let secret = MiniSecretKey::from_bytes(&[7_u8; 32])
            .unwrap()
            .expand(ExpansionMode::Ed25519);
        let ed25519_secret = secret.to_ed25519_bytes();
        let mut output = [0_u8; SECRET_KEY_LENGTH];

        assert!(!convert(&ed25519_secret[..63], &mut output));
        assert!(!convert(&ed25519_secret, &mut output[..63]));
        assert!(!unsafe {
            sora_sr25519_secret_from_ed25519(
                std::ptr::null(),
                SECRET_KEY_LENGTH,
                output.as_mut_ptr(),
                output.len(),
            )
        });
        assert!(!unsafe {
            sora_sr25519_secret_from_ed25519(
                ed25519_secret.as_ptr(),
                ed25519_secret.len(),
                std::ptr::null_mut(),
                SECRET_KEY_LENGTH,
            )
        });
    }

    #[test]
    fn conversion_contains_panics_and_clears_output() {
        let input = [7_u8; SECRET_KEY_LENGTH];
        let mut output = [0xff_u8; SECRET_KEY_LENGTH];

        let result = unsafe {
            convert_ed25519_secret_with(
                input.as_ptr(),
                input.len(),
                output.as_mut_ptr(),
                output.len(),
                |_| -> Option<[u8; SECRET_KEY_LENGTH]> {
                    panic!("forced conversion containment test")
                },
            )
        };

        assert!(!result);
        assert!(output.iter().all(|byte| *byte == 0));
    }

    #[test]
    fn contains_panics_before_the_ffi_boundary() {
        assert!(sora_sr25519_validator_contains_forced_panic());
    }
}
