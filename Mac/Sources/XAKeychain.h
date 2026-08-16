/* XAKeychain.h
 *
 * Server and NickServ passwords, kept in the login keychain rather than in
 * servlist_.conf. Plain C so the xchat core can call it.
 */

#ifndef XCHAT_CERULEAN_KEYCHAIN_H
#define XCHAT_CERULEAN_KEYCHAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Both take a network name and a kind, which is "server" or "nickserv". */

/* Returns a malloc'd copy of the secret, or NULL when there is none. The
 * caller frees it. */
char *xa_keychain_get (const char *network, const char *kind);

/* Stores the secret, replacing whatever was there. A NULL or empty secret
 * removes the entry. */
void xa_keychain_set (const char *network, const char *kind, const char *secret);

#ifdef __cplusplus
}
#endif

#endif /* XCHAT_CERULEAN_KEYCHAIN_H */
