# frntn/vault-unattended-pki

### Prerequisites

The following binaries are in your system's PATH :

- bash >=4.3
- vault >=0.9.0

### Usage 

Start the script

```bash
$ ./demo.sh
```

### What it does

Basically the script starts vault, and use its `pki` mount point to create and configure :

- The ROOT Certificate Authority
- An INTERMEDIATE Certificate Authority


It then create and use relevant token (i.e. _"user session"_) w/ attached policy (i.e. _"access control list"_) to issue server and client certificate.

Last step shows how to create a P12 archive with the client cert and private key

### TODO

- [] Add TravisCI
