#!/usr/bin/env bash

set -e

# update_fqdn - Updates jenkins fqdn for server name and certificate names
# Arguments:
#    $1 - FQDN
#    $2 - Filename
function update_fqdn() {
    sed -i -Ee "s/(.*)jenkins_fqdn(.*)/\1$1\2/g" $2
}


# update_service_url - Updates jenkins service url for proxy_pass
# Arguments:
#    $1 - Full URL
#    $2 - Filename
function update_service_url() {
    sed -i -Ee "s/(.*proxy_pass.*)jenkins-master(.*)/\1$1\2/g" $2
}

ssl_enabled=0

while [[ $# -gt 0 ]]
do
    case $1 in
        -ssl|--ssl-enabled)
            ssl_enabled=1
        ;;
    esac
    shift
done

if [[ $ssl_enabled -gt 0 ]]
then
    rm -f /etc/nginx/conf.d/jenkins-http.conf
    update_fqdn $JENKINS_FQDN /etc/nginx/conf.d/jenkins-https.conf
    [[ ! -z $JENKINS_SERVICE ]] && update_service_url $JENKINS_SERVICE /etc/nginx/conf.d/jenkins-https.conf

    # Issue certificate from letsencrypt and install in nginx folder
    [[ -z $ACME_DNSSLEEP ]] && ACME_DNSSLEEP=60
    set +e
    /root/.acme.sh/acme.sh --issue -d $JENKINS_FQDN --dns dns_lexicon --dnssleep $ACME_DNSSLEEP
    exitcode=$?
    if [ $exitcode -ne 0 ] && [ $exitcode -ne 2 ]; then exit $exitcode; fi
    if [ $exitcode -eq 0 ]
    then
        /root/.acme.sh/acme.sh --install-cert -d $JENKINS_FQDN --key-file /etc/nginx/ssl/${JENKINS_FQDN}_key.pem \
            --fullchain-file /etc/nginx/ssl/${JENKINS_FQDN}_cert.pem \
            --reloadcmd "nginx -s reload"
    fi
    set -e
else
    rm -f /etc/nginx/conf.d/jenkins-https.conf
    update_fqdn $JENKINS_FQDN /etc/nginx/conf.d/jenkins-http.conf
    [[ ! -z $JENKINS_SERVICE ]] && update_service_url $JENKINS_SERVICE /etc/nginx/conf.d/jenkins-http.conf
fi

exec nginx -g "daemon off;"
