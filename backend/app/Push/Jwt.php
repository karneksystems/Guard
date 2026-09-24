<?php

namespace App\Push;

use OpenSSLAsymmetricKey;
use RuntimeException;

/**
 * The two JWTs the push providers want: ES256 for APNs token auth, RS256 for
 * Google's OAuth2 service-account exchange. Small enough to own rather than pull
 * in a library, and covered by tests that verify the signatures with OpenSSL.
 */
final class Jwt
{
    public static function es256(array $header, array $claims, string $pem): string
    {
        $key = self::key($pem);
        $input = self::b64(json_encode($header + ['alg' => 'ES256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR))
            . '.' . self::b64(json_encode($claims, JSON_THROW_ON_ERROR));
        if (!openssl_sign($input, $der, $key, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('ES256 signing failed');
        }

        return $input . '.' . self::b64(self::derToRaw($der, 32));
    }

    public static function rs256(array $header, array $claims, string $pem): string
    {
        $key = self::key($pem);
        $input = self::b64(json_encode($header + ['alg' => 'RS256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR))
            . '.' . self::b64(json_encode($claims, JSON_THROW_ON_ERROR));
        if (!openssl_sign($input, $sig, $key, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('RS256 signing failed');
        }

        return $input . '.' . self::b64($sig);
    }

    public static function b64(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    public static function unb64(string $s): string
    {
        return base64_decode(strtr($s, '-_', '+/') . str_repeat('=', (4 - strlen($s) % 4) % 4), true) ?: '';
    }

    private static function key(string $pem): OpenSSLAsymmetricKey
    {
        $key = openssl_pkey_get_private($pem);
        if ($key === false) {
            throw new RuntimeException('Cannot read private key: ' . openssl_error_string());
        }

        return $key;
    }

    /** OpenSSL gives an ASN.1 DER ECDSA signature; JWS wants r||s, each left-padded to the curve size. */
    public static function derToRaw(string $der, int $size): string
    {
        $pos = 2; // 0x30 len
        if (ord($der[1]) & 0x80) {
            $pos += ord($der[1]) & 0x7f;
        }
        $parts = [];
        for ($i = 0; $i < 2; $i++) {
            if (ord($der[$pos]) !== 0x02) {
                throw new RuntimeException('Bad DER signature');
            }
            $len = ord($der[$pos + 1]);
            $int = substr($der, $pos + 2, $len);
            $pos += 2 + $len;
            $int = ltrim($int, "\x00");
            $parts[] = str_pad($int, $size, "\x00", STR_PAD_LEFT);
        }

        return $parts[0] . $parts[1];
    }

    /** Inverse of derToRaw, for tests that verify with openssl_verify. */
    public static function rawToDer(string $raw, int $size): string
    {
        $enc = static function (string $int): string {
            $int = ltrim($int, "\x00");
            if ($int === '' || ord($int[0]) & 0x80) {
                $int = "\x00" . $int;
            }

            return "\x02" . chr(strlen($int)) . $int;
        };
        $body = $enc(substr($raw, 0, $size)) . $enc(substr($raw, $size));

        return "\x30" . chr(strlen($body)) . $body;
    }
}
