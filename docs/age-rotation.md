# Key & Secret Rotation Runbook

How to rotate the age passphrase, the age identity, and the SSH keypair
that this repo's encryption depends on. Read "Moving parts" first; each
procedure ends with verification and rollback.

## When to rotate

- Suspected compromise of the passphrase, identity file, or a host → rotate immediately (Procedure B for identity, C for SSH; A alone only if just the passphrase leaked).
- Routine hygiene or algorithm upgrade → Procedure A/C as desired; B rarely.

## Moving parts

| Artifact | Location | Notes |
|---|---|---|
| Plaintext age identity | `~/.keys/age.key` on every host | What chezmoi decrypts with |
| Passphrase-encrypted identity | `rvenutolo/crypt` repo, `keys/age.key` | Only consumed by fresh bootstraps (`run_once_before_01-get-keys.sh.tmpl`) |
| Age recipient (public key) | `.chezmoidata.yaml` → `age.public_key` | Single source; `.chezmoi.toml.tmpl` reads it at init |
| Ciphertext checksums | `.chezmoidata.yaml` → `checksums:` | `crypt_age_key`, `crypt_id_ed25519`, `crypt_id_ed25519_pub`; get-keys aborts on mismatch |
| Encrypted files (22) | 18 `encrypted_*` sources + 4 root `.work-*.age` template inputs | All ASCII-armored age files, same recipient; 2 of the 18 `encrypted_*` files (`dot_config/exact_git/encrypted_private_config-personal.private.tmpl` and `dot_config/exact_git/encrypted_private_config-work.private.tmpl`) carry no `.age` suffix |
| SSH keypair | `~/.keys/id_ed25519{,.pub}` on every host; encrypted copies in crypt | `authorized_keys` renders live from the GitHub account's keys (`gitHubKeys "rvenutolo"`) |

All 22 encrypted files in this repo are ASCII-armored and share the single
recipient pinned in `.chezmoidata.yaml`, so every decrypt in these
procedures uses the same invocation shape: `age --decrypt --identity
~/.keys/age.key <file>`. Two of them
(`dot_config/exact_git/encrypted_private_config-personal.private.tmpl` and
`dot_config/exact_git/encrypted_private_config-work.private.tmpl`) are
armored age ciphertext without a `.age` suffix, so `git ls-files '*.age'`
undercounts them — enumerate by content instead (see Procedure B).

## Procedure A: passphrase rotation

Existing hosts are unaffected (they already hold the plaintext identity);
only future bootstraps consume the crypt copy.

1. Re-encrypt the identity under a new passphrase (prompts interactively):

   ```shell
   age --encrypt --passphrase --armor --output /tmp/age.key.new ~/.keys/age.key
   ```

2. Record the new ciphertext checksum and update `checksums.crypt_age_key`
   in `.chezmoidata.yaml` (worktree + PR as usual):

   ```shell
   sha256sum /tmp/age.key.new
   ```

3. Replace `keys/age.key` in the `rvenutolo/crypt` repo with
   `/tmp/age.key.new` (commit + push there), then `rm /tmp/age.key.new`.

**Verify:** fresh-bootstrap simulation — in a throwaway `HOME`, run the
get-keys script and confirm it downloads, checksum-passes, and decrypts
with the new passphrase.
**Rollback:** revert the crypt commit and the chezmoidata checksum bump;
the old passphrase copy is back.

## Procedure B: full identity rotation

Requires the OLD identity present at `~/.keys/age.key` until re-encryption
is done. Do all repo work in a worktree.

1. Generate the new identity and capture its recipient:

   ```shell
   age-keygen --output ~/.keys/age.key.new
   new_recipient="$(age-keygen -y ~/.keys/age.key.new)"
   ```

2. Re-encrypt every armored age file in the repo. Enumerate by content, not
   by `.age` suffix — `git ls-files '*.age'` misses the two
   `dot_config/exact_git/encrypted_*.private.tmpl` files, which are armored
   age ciphertext without that suffix (see "Moving parts"). Run under
   `set -euo pipefail` so a failed decrypt aborts the loop instead of
   silently clobbering the original with an empty-plaintext ciphertext:

   ```shell
   set -euo pipefail
   git grep --files-with-matches -- '-----BEGIN AGE ENCRYPTED FILE-----' | while IFS= read -r f; do
     age --decrypt --identity ~/.keys/age.key "${f}" \
       | age --encrypt --armor --recipient "${new_recipient}" --output "${f}.tmp"
     mv "${f}.tmp" "${f}"
   done
   ```

3. Update `age.public_key` in `.chezmoidata.yaml` to `${new_recipient}`.
4. Run Procedure A steps 1–3 against `~/.keys/age.key.new` to publish the
   new passphrase-encrypted copy and checksum.
5. Merge the PR, then roll out per host, one at a time:

   ```shell
   mv ~/.keys/age.key.new ~/.keys/age.key   # or scp from the rotation host
   chezmoi update       # pull + apply
   chezmoi verify
   ```

**Verify (before merging):** per-file, confirm every re-encrypted file
decrypts with the new identity and NOT with the old one:

```shell
age --decrypt --identity ~/.keys/age.key.new "${f}" >/dev/null
```

`chezmoi --source <worktree> diff` cannot be used for this check yet —
chezmoi's configured identity (`~/.keys/age.key`) still holds the OLD key
until step 5's swap, so it would fail on every re-encrypted file. Run the
`chezmoi diff` check only after step 5, as a post-swap sanity check.
**Rollback:** `git revert` the rotation commit(s); every host still holds
the old identity until step 5, so reverting restores a working state. Do
not delete old identity copies until all hosts verify clean.

## Procedure C: SSH keypair rotation

1. Generate the new keypair:

   ```shell
   ssh-keygen -t ed25519 -f ~/.keys/id_ed25519.new -C 'venutolo@hotmail.com'
   ```

2. Add the new public key to the GitHub account (this feeds
   `dot_config/exact_ssh/authorized_keys.tmpl` via `gitHubKeys`), keep the
   old one until rollout finishes:

   ```shell
   gh ssh-key add ~/.keys/id_ed25519.new.pub --title "shared key $(date +%Y-%m-%d)"
   ```

3. Encrypt both halves for crypt and pin the new checksums in
   `.chezmoidata.yaml` (`crypt_id_ed25519`, `crypt_id_ed25519_pub`):

   ```shell
   recipient="$(yq '.age.public_key' .chezmoidata.yaml)"
   age --encrypt --armor --recipient "${recipient}" --output /tmp/id_ed25519 ~/.keys/id_ed25519.new
   age --encrypt --armor --recipient "${recipient}" --output /tmp/id_ed25519.pub ~/.keys/id_ed25519.new.pub
   sha256sum /tmp/id_ed25519 /tmp/id_ed25519.pub
   ```

4. Replace `keys/id_ed25519{,.pub}` in crypt; merge the chezmoidata PR.
5. Per host: install the new key, re-render, confirm access:

   ```shell
   mv ~/.keys/id_ed25519.new ~/.keys/id_ed25519
   mv ~/.keys/id_ed25519.new.pub ~/.keys/id_ed25519.pub
   chezmoi update
   ssh -T git@github.com
   ```

6. After every host verifies: remove the OLD public key from the GitHub
   account (`gh ssh-key list` / `gh ssh-key delete`). `authorized_keys`
   drops it on the next `chezmoi apply`.

Config paths never change: `dot_config/exact_ssh/config.tmpl` and
`profile.sh.tmpl` reference `.keys/id_ed25519` by path.

**Verify:** `ssh -T git@github.com` and host-to-host ssh with the new key;
fresh-bootstrap simulation as in Procedure A.
**Rollback:** old private key still on hosts and old public key still on
GitHub until step 6 — reverting the crypt/chezmoidata commits restores the
previous state.
