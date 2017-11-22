# frntn/vault-unattended-pki

## Prerequisites

The following binaries are in your system's PATH :

- bash >=4.3
- vault >=0.9.0

## Usage 

Start the script

```bash
$ ./demo.sh
```

## What it does

Basically the script starts vault, and use its `pki` mount point to create and configure :

- The ROOT Certificate Authority
- An INTERMEDIATE Certificate Authority


It then create and use relevant token (i.e. _"user session"_) w/ attached policy (i.e. _"access control list"_) to issue server and client certificate.

Last step shows how to create a P12 archive with the client cert and private key

## Output Files

See `.gitignore` for list of generated files with relevant comment

If you want to check your generated server certificate (for example) :
```bash
$ openssl x509 -in server.pem.crt -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            2f:24:73:83:86:11:d9:1b:70:ef:86:16:9b:54:d4:2a:6f:94:1a:db
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: CN=ACME Authority - L1
        Validity
            Not Before: Nov 22 14:07:00 2017 GMT
            Not After : Nov 25 14:07:30 2017 GMT
        Subject: CN=admin.staging.acme.inc
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub: 
                    04:7e:0b:38:0b:4e:53:1b:41:81:28:31:48:05:12:
                    8c:09:56:a9:eb:bb:58:d4:fd:83:7d:bf:51:5c:a6:
                    57:25:db:5a:3c:53:10:9d:1e:78:38:1a:78:bd:70:
                    1f:5d:cc:29:36:cc:26:6a:d1:04:da:d0:2d:14:f1:
                    f4:b9:c7:cc:3a
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Subject Key Identifier: 
                FF:61:BA:80:65:E1:E2:03:5C:E2:74:82:DD:EB:8F:11:84:3F:53:EC
            X509v3 Authority Key Identifier: 
                keyid:84:C4:EB:0A:30:86:78:7B:F3:C8:CB:9B:8B:9F:86:3F:7F:63:01:B9

            Authority Information Access: 
                CA Issuers - URI:https://pki.acme.inc/l1/ca

            X509v3 Subject Alternative Name: 
                DNS:admin.staging.acme.inc
            X509v3 CRL Distribution Points: 

                Full Name:
                  URI:https://pki.acme.inc/l1/crl

    Signature Algorithm: ecdsa-with-SHA256
         30:46:02:21:00:d7:81:f9:ab:1e:00:b1:cc:98:f4:bf:4a:c0:
         6d:fe:a7:a0:ae:23:7a:8b:11:f8:22:2b:3a:51:e9:ab:a0:aa:
         1f:02:21:00:d6:d7:50:1c:f6:fc:a7:79:4b:e1:62:cc:9f:3f:
         bb:ae:02:42:d5:e5:dd:79:e0:57:e3:36:76:1e:79:51:75:b3

```

## TODO

- [ ] Add TravisCI
