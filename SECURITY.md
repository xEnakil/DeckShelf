# Security policy

## Supported versions

Security fixes are applied to the latest published release and the `main` branch.

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use [GitHub's private security advisory form](https://github.com/xEnakil/DeckShelf/security/advisories/new) and include:

- the affected version and platform;
- steps or a minimal proof of concept;
- the expected security impact;
- any suggested mitigation.

Avoid including real ROM lists, usernames or filesystem paths. You should receive an acknowledgement within seven days. A fix and disclosure timeline will be coordinated after the report is reproduced.

## Security boundaries

ROM Shelf reads filenames and file metadata from a directory chosen by the user. It does not upload library data, download ROMs or execute discovered game files. The native app exposes its self-contained page only through a random loopback URL and applies a restrictive content-security policy.

The published executable is currently unsigned. Always compare release checksums when downloading from anywhere other than the official GitHub release page.

