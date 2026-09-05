# Mail Authentication: SPF, DKIM, DMARC

How `graylining.com` proves its outgoing mail is genuine, so receivers like Gmail
put it in the inbox instead of spam.

## Current state

| Element | Value | Where |
|---|---|---|
| SPF | `v=spf1 mx -all` | TXT on `graylining.com` |
| DKIM (RSA) | `v=DKIM1; k=rsa; p=MIIBIjANBgkq…` | TXT on `v1-rsa-20260801._domainkey` |
| DKIM (Ed25519) | `v=DKIM1; k=ed25519; p=s6KkjUHV…` | TXT on `v1-ed25519-20260801._domainkey` |
| DMARC | `v=DMARC1; p=none; rua=mailto:system@graylining.com; fo=1` | TXT on `_dmarc` |
| Reverse DNS | `mail.graylining.com` | set at the hosting provider |

All DNS records live at **Namecheap → Advanced DNS → Host Records** as TXT
entries. The "Mail Settings" section is only for choosing an email *service* and
manages MX records - authentication records do not go there.

Namecheap wants the **host** portion only: `v1-rsa-20260801._domainkey`, not the
fully-qualified name.

## How the pieces fit

- **SPF** says which servers may send as this domain. `mx` authorises whatever the
  MX points at (this server); `-all` means "reject anything else", which is strict
  and correct here.
- **DKIM** cryptographically signs each message. Stalwart holds the private key and
  publishes the public key in DNS, so receivers can verify the message was not
  altered and genuinely came from this domain.
- **DMARC** tells receivers what to do when SPF and DKIM disagree with the From
  address, and where to send reports.

Stalwart signs with **both** an Ed25519 and an RSA key. Receivers use whichever
they support; RSA is the universally accepted one, Ed25519 is smaller and modern.
Publishing both is deliberate.

## The rotation trap

The selectors contain a date (`…20260801`) because Stalwart's **automatic DKIM
management** rotates keys on a schedule. That feature is designed to work with
Stalwart's DNS management layer, which publishes replacement records through a DNS
provider's API.

**Our DNS is edited by hand at Namecheap.** So when Stalwart rotates a key, the new
selector has no DNS record, and DKIM silently stops validating. Mail still sends
and still arrives - it just stops being trusted, which is the hardest kind of
failure to notice.

Mitigation: **disable automatic rotation** so the selectors stay fixed, or monitor
for drift. Fixed selectors are the pragmatic choice while DNS is manual.

## Verifying

Records resolve and are well-formed:

```bash
dig +short TXT v1-rsa-20260801._domainkey.graylining.com @8.8.8.8
dig +short TXT v1-ed25519-20260801._domainkey.graylining.com @8.8.8.8
dig +short TXT _dmarc.graylining.com @8.8.8.8
dig +short TXT graylining.com @8.8.8.8 | grep spf
```

A long RSA key comes back split across two quoted strings. That is normal - DNS
resolvers rejoin them. Check it starts `MIIBIjANBgkq` and ends `IDAQAB`; a
truncated key fails silently.

Which selector is actually signing right now (useful after a suspected rotation):

```bash
# send yourself a message, then read its DKIM-Signature header over IMAP
# the s= value is the live selector - it MUST have a matching DNS record
```

**Signatures cannot be validated on this server.** Stalwart does not DKIM-verify
mail it signed itself and delivered locally, so a self-sent message has no
`Authentication-Results` header. That is expected. Validation only happens at a
receiving server, so test externally:

- Send to a Gmail address, open the message, **Show original** - want `SPF: PASS`,
  `DKIM: PASS`, `DMARC: PASS`
- Or `https://www.mail-tester.com` for a score and a list of weaknesses

## Tightening DMARC

`p=none` means "monitor only" - receivers report but never act. That is the correct
starting point, because a misconfiguration under a strict policy silently destroys
legitimate mail.

Once aggregate reports (arriving at `system@graylining.com`) show mail passing
consistently for a week or two, tighten in order:

```
p=none  ->  p=quarantine  ->  p=reject
```

Do not skip straight to `p=reject`.
