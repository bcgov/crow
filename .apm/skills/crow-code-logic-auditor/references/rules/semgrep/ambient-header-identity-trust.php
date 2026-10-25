<?php

function get_user_unsafe($req) {
    // ruleid: php-ambient-header-identity-trust
    $user = $_SERVER['HTTP_SM_USER'];
    // ruleid: php-ambient-header-identity-trust
    $azure = $_SERVER['HTTP_X_MS_CLIENT_PRINCIPAL'];
    return $user;
}

function get_user_psr7($req) {
    // ruleid: php-ambient-header-identity-trust
    return $req->headers->get('sm_user');
}

function get_user_safe($req) {
    if (!verifySignature($req)) {
        throw new \Exception("Unauthorized");
    }
    // ok: php-ambient-header-identity-trust
    return $_SERVER['HTTP_SM_USER'];
}
