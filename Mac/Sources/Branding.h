/* Branding.h
 *
 * Single source of truth for product identity. Everything user-visible that
 * names the application should come from here rather than being spelled out
 * again at the call site.
 *
 * The version itself is NOT defined here: it is generated into
 * build_number.h by tools/gen_buildnum_h.pl, seeded from the first token of
 * the top-level "Changes" file.
 */

#ifndef XCHAT_CERULEAN_BRANDING_H
#define XCHAT_CERULEAN_BRANDING_H

/* Full product name. Also names the Application Support folder, so changing
 * it strands existing user configuration. */
#define XA_PRODUCT_NAME     "XChat Cerulean"

/* Short form, used where the full name is redundant (window title prefixes). */
#define XA_PRODUCT_SHORT    "Cerulean"

#define XA_BUNDLE_ID        "dev.vdmkenny.xchatcerulean"
#define XA_HOMEPAGE         "https://github.com/vdmkenny/xchat-cerulean"

/* What this fork descends from, for about boxes and attribution. */
#define XA_UPSTREAM_NAME    "X-Chat Aqua"
#define XA_UPSTREAM_URL     "https://github.com/xchataqua/xchataqua"

#endif /* XCHAT_CERULEAN_BRANDING_H */
