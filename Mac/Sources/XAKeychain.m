/* XAKeychain.m
 *
 * See XAKeychain.h.
 */

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "Branding.h"
#import "XAKeychain.h"

/* One service per kind, so a network's server password and its NickServ
 * password can both be stored under the network's name. */
static NSString *XAKeychainService (const char *kind)
{
    return [NSString stringWithFormat:@"%s (%s)", XA_PRODUCT_NAME, kind ? kind : "server"];
}

static NSMutableDictionary *XAKeychainQuery (const char *network, const char *kind)
{
    if (network == NULL || network[0] == '\0') return nil;

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(id)kSecClass] = (id)kSecClassGenericPassword;
    query[(id)kSecAttrService] = XAKeychainService (kind);
    query[(id)kSecAttrAccount] = @(network);
    return query;
}

char *xa_keychain_get (const char *network, const char *kind)
{
    NSMutableDictionary *query = XAKeychainQuery (network, kind);
    if (query == nil) return NULL;

    query[(id)kSecReturnData] = @YES;
    query[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    if (SecItemCopyMatching ((CFDictionaryRef)query, &result) != errSecSuccess)
        return NULL;

    /* SecItemCopyMatching returns a retained object. */
    NSData *data = [(NSData *)result autorelease];
    if ([data length] == 0) return NULL;

    char *secret = malloc ([data length] + 1);
    if (secret == NULL) return NULL;

    memcpy (secret, [data bytes], [data length]);
    secret[[data length]] = '\0';
    return secret;
}

void xa_keychain_set (const char *network, const char *kind, const char *secret)
{
    NSMutableDictionary *query = XAKeychainQuery (network, kind);
    if (query == nil) return;

    if (secret == NULL || secret[0] == '\0') {
        SecItemDelete ((CFDictionaryRef)query);
        return;
    }

    NSData *data = [@(secret) dataUsingEncoding:NSUTF8StringEncoding];

    /* Update in place when the entry exists, so the keychain does not
     * accumulate duplicates for the same network. */
    NSDictionary *update = @{(id)kSecValueData: data};
    if (SecItemUpdate ((CFDictionaryRef)query,
                       (CFDictionaryRef)update) == errSecSuccess)
        return;

    query[(id)kSecValueData] = data;
    query[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleWhenUnlocked;
    SecItemAdd ((CFDictionaryRef)query, NULL);
}
