# SpamAssassin -> rspamd migration

Written for this specific box: Debian 12 (bookworm), Postfix 3.7.11, Dovecot
2.3.19, spamass-milter + OpenDKIM on the milter chain, postscreen + SPF
already handling connection-level filtering. ~960Mi RAM, already swapping —
scripts account for that (redis capped at 64mb maxmemory).

## What this does

- Installs rspamd + redis from the official rspamd.com repo
- Adds rspamd as a milter on `127.0.0.1:11332`, next to your existing
  OpenDKIM milter on `127.0.0.1:8891` (DKIM is untouched — out of scope)
- Removes spamass-milter from Postfix's milter chain, then stops the
  SpamAssassin services (packages stay installed until you `--purge`)
- Updates the Dovecot Sieve rule that files spam into Junk, to key off
  rspamd's own headers instead of SpamAssassin's `X-Spam-Flag`
- Adds Dovecot IMAPSieve + sieve_extprograms so moving mail into/out of
  Junk trains rspamd's Bayes classifier via `rspamc learn_spam`/`learn_ham`
  — this is new; your old setup only tagged mail, it never learned from it
- Enables rspamd's greylisting module (redis-backed)
- Fixes a pre-existing bug in `main.cf` line 69 where `milter_protocol` and
  `smtpd_helo_required` were mashed onto one line with no newline —
  `smtpd_helo_required=yes` was silently never active. Flagged separately,
  skip with `03-configure-postfix.sh --skip-helo-fix` if you'd rather not.

## What this deliberately does NOT touch

- OpenDKIM — already working, re-plumbing DKIM keys is a separate project
- postscreen / DNSBL config — already doing connection-stage filtering
- policyd-spf — already wired in
- `smtpd_recipient_restrictions` / `smtpd_sender_restrictions` — already
  cover what a generic "harden Postfix" checklist would suggest

## Run order

```
sudo bash 00-detect.sh              # read-only, review before proceeding
sudo bash 01-install-rspamd.sh
sudo bash 02-configure-rspamd.sh
sudo bash 03-configure-postfix.sh
sudo bash 04-disable-spamassassin.sh
sudo bash 05-dovecot-autolearn.sh
sudo bash 06-verify.sh              # read-only, checks everything above
```

Every script that edits a config file backs it up first to
`/root/rspamd-migration-backups/<script-name>-<timestamp>/`, and refuses to
reload/restart a service if the new config fails validation
(`postfix check` / `doveconf -n`).

## Optional (separate, read the header comments first)

- `optional/10-strict-smtp-hardening.sh` — adds the one genuinely missing
  HELO check; everything else from the generic "strict SMTP restrictions"
  checklist is already in place on this box
- `optional/11-tls-auth-hardening.sh` — disables plaintext Dovecot auth and
  raises the TLS floor to 1.2. Real behavior change, test your mail clients
  after running it.

## Rollback

Each backup dir mirrors the real path, e.g. to undo the Postfix change:

```
sudo cp /root/rspamd-migration-backups/03-configure-postfix-<timestamp>/etc/postfix/main.cf /etc/postfix/main.cf
sudo postfix reload
sudo systemctl enable --now spamass-milter spamd
```

## Bayes training note

rspamd's controller (port 11334, used by `rspamc learn_*`) has no auth
password configured by default here since it's loopback-only on a
single-admin box. If that ever changes, set a controller password in
`/etc/rspamd/local.d/worker-controller.inc` and add `-P <password>` to the
two scripts in `/etc/dovecot/sieve/scripts/`.
