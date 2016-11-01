# Acmedocker

[![Docker Repository on Quay](https://quay.io/repository/pheonyx/acmedocker/status "Docker Repository on Quay")](https://quay.io/repository/pheonyx/acmedocker)

Create and renew Let's encrypt certificates easily (only fonr nginx based server)

## Directory layout
* `/certs` contains generated certificates and, optionnally, `dhparams.pem` file
* `/nginx` contains generated `.acme-nginx` file, to include in your nginx server files -- **do not edit**


## Usage
To run this container, you must mount the directories above (`/certs` and `/nginx`) and add `LETSENCRYPT_EMAIL` to the container environment.

For example: 

```sh
docker run -d --name container_name \
    -v /etc/nginx/conf.d:/nginx \
    -v /etc/nginx/certs:/certs \
    -e LETSENCRYPT_EMAIL=email@nobody.tld \
    pheonyx/acmedocker:stable
```

Then, to Create new certificates, you only run :

```sh
docker exec container_name acmedocker want domain.tld
```

To help you, when you create the container, an help is displayed


## Options
Following environment variables are available:
* **LETSENCRYPT_EMAIL**: registration email (**mandatory**)
* **STAGING_MODE**: if `true`, acmetool use the staging url of let's encrypt (allow you to get 30k certificates per week instead of 5, usefull for test) [_default_: `false`]
* **KEY_TYPE**: key type for certificates (`rsa`/`ecdsa`) [_default_: `ecdsa`]
* **RSA_SIZE**: rsa size key [_default_: `2048`]
* **ECDSA_CURVE**: algorithm name for ecdsa (`nistp256`/`nistp384`/`nistp521`) [_default_: `nistp256`]
* **DHPARAM_SIZE**: if is set, the container generate an `dhparams.pem` file with `DHPARAM_SIZE` for size [_default_: `none`]