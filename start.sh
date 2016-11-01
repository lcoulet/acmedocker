#!/bin/bash

# TODO : Faire en sorte de regenerer le nginx a chaque redemarage (au cas ou)

## S T A R T  P A T H   C O N F I G U R A T I O N S
_PATH_PROXY="/nginx"
_PATH_CERTS="/certs"

_PATH_LOG="/var/log/acmetool"
_PATH_QS="/etc/acmetool/quickstart.yaml"
_PATH_ACCOUNT="/var/lib/acme/accounts"
_PATH_CRON="/var/spool/cron/crontabs/root"
_FILE_PROXY=".acme-nginx"
## S T A R T  P A T H   C O N F I G U R A T I O N S
## S T A R T  M E S S A G E S   L I S T
_EMAIL_NOT_SET="!!! You don't have set your email. Add \e[96mLETSENCRYPT_EMAIL\e[91m environment variable !!!"
_PROXY_NOT_SET="!!! You don't have set nginx conf volume. Add \e[96m$_PATH_PROXY\e[91m in volumes informations !!!"
_CERTS_NOT_SET="!!! You don't have set certs volume. Add \e[96m$_PATH_CERTS\e[91m in volumes informations !!!"
_QUICKSTART_FAILED="!!! Acmetool configuration failed !!!"

_TITLE_QUICKSTART="[Acmetool Quickstart]"
_QS_CONF="    - Configure quickstart.yaml"
_QS_STAGING="    * Staging mode enabled"
_QS_RUN="    - Quickstart acmetool"
_QS_CRON="    - Install crons to renew"
_QS_DHPARAM="    - Generate dhparams.pem"
_QS_SUCCESS="    - Acmetool successfully configured"

_GEN_PROXY="    - Add nginx stateless configuration"


_TITLE_HOWTO="[How to use it]"
_HT_HELP_NGIX="    Add \e[96minclude conf.d/$_FILE_PROXY\e[39m in your nginx configuration file(s)"
_HT_HELP_CMD="    $> docker exec $(grep 'docker/' /proc/1/cgroup | tail -1 | sed 's/^.*\///' | cut -c 1-12) acmedocker want domain.tld"
## E N D   M E S S A G E S   L I S T
## S T A R T   F U N C T I O N S
function sendMessage { echo -e "$@" | tee -a "$_PATH_LOG"; }
function sendFatal { echo -e "\e[91m$(sendMessage "$@")\e[39m"; }
function sendSuccess { echo -e "\e[92m$(sendMessage "$@")\e[39m"; }
function sendInformation { echo -e "\e[93m$(sendMessage "$@")\e[39m"; }

function envChecker()
{
    if [ "$LETSENCRYPT_EMAIL" == "" ]; then
        sendFatal "$_EMAIL_NOT_SET"
        ENV_FAILED="true"
    fi

    if [ ! -d $_PATH_PROXY ]; then
        sendFatal "$_PROXY_NOT_SET"
        ENV_FAILED="true"
    fi
    if [ ! -d $_PATH_CERTS ]; then
        sendFatal "$_CERTS_NOT_SET"
        ENV_FAILED="true"
    fi

    if [ "$ENV_FAILED" == "true" ]; then
        exit 1
    fi
}

function firstStart
{
    ## Start Quickstart initialization
    sendMessage "$_TITLE_QUICKSTART"


    ## Check environment
    envChecker
    echo > $_PATH_PROXY/$_FILE_PROXY


    ## Configure response file for acmetool
    sendMessage "$_QS_CONF"

    # Staging mode
    if [ "${STAGING_MODE,,}" == "true" ]; then
        sendInformation "$_QS_STAGING"
        URL=https://acme-staging.api.letsencrypt.org/directory
    else
        URL=https://acme-v01.api.letsencrypt.org/directory
    fi

    # Key type
    echo "# Certificate key configurations" >> $_PATH_QS
    if [ "${KEY_TYPE,,}" == "rsa" ]; then
        RSA_SIZE=${RSA_SIZE:-2048}
        {
            echo "acmetool-quickstart-key-type": "rsa"
            echo "acmetool-quickstart-rsa-key-size": "$RSA_SIZE"
        } >> $_PATH_QS
    else
        if [ "${ECDSA_CURVE,,}" != "nistp384" ] && [ "${ECDSA_CURVE,,}" != "nistp521" ]; then
            ECDSA_CURVE="nistp256"
        fi
        {
            echo "acmetool-quickstart-key-type": "ecdsa"
            echo "acmetool-quickstart-rsa-key-size": "${ECDSA_CURVE,,}"
        }  >> $_PATH_QS
    fi

    # Acme configuration
    {
        echo "# ACME configuration"
        echo "acme-enter-email": "${LETSENCRYPT_EMAIL}"
        echo "acmetool-quickstart-choose-server": $URL
    } >> $_PATH_QS


    ## Generate dhparam
    if [ ! -z "$DHPARAM_SIZE" ]; then
        sendMessage "$_QS_DHPARAM ($DHPARAM_SIZE bits)"
        openssl dhparam -out "$_PATH_CERTS/dhparams.pem" "$DHPARAM_SIZE"
    fi


    ## Run acmetool
    sendMessage "$_QS_RUN"
    LTMP=$(mktemp)
    if ! acmetool quickstart --response-file=$_PATH_QS 2> "$LTMP" > /dev/null; then
        sendFatal "$_QUICKSTART_FAILED"
        cat "$LTMP"
        cat "$LTMP" >> "$_PATH_LOG"
        rm "$LTMP"
        rm -rf ${_PATH_ACCOUNT:?}/*
        exit 2
    fi


    ## Create cron
    sendMessage "$_QS_CRON"
    cat >> $_PATH_CRON << EOF

## Acmetool reconcile
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
EOF
    echo "$(echo $RANDOM | head -c 1) $(echo $RANDOM | head -c 1) * * * /bin/acmedocker reconcile" >> $_PATH_CRON

    sendSuccess "$_QS_SUCCESS"
}

function proxyConfig
{
    sendMessage "$_GEN_PROXY"

    {
        echo -e 'location ~ "^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$" {'
        echo -e '\tdefault_type text/plain;'
        echo -e "\treturn 200 \"\$1.$(acmetool account-thumbprint | cut -f1)\";"
        echo -e '}'
    } > $_PATH_PROXY/$_FILE_PROXY
}

function howToUseIt
{
    sendMessage "$_TITLE_HOWTO"
    sendMessage "$_HT_HELP_NGIX"
    echo "$_HT_HELP_CMD" >> $_PATH_LOG
}
## E N D   F U N C T I O N S

crond
if [ "$(ls $_PATH_ACCOUNT 2> /dev/null)" == "" ]; then
    firstStart
fi
proxyConfig
howToUseIt

tail -n 1 -f $_PATH_LOG