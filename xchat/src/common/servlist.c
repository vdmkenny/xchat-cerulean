/* X-Chat
 * Copyright (C) 1998 Peter Zelezny.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include "xchat.h"
#include <glib.h>

#include "cfgfiles.h"
#include "fe.h"
#include "server.h"
#include "text.h"
#include "util.h" /* token_foreach */
#include "xchatc.h"

#include "servlist.h"
#include "XAKeychain.h"


struct defaultserver
{
	char *network;
	char *host;
	char *channel;
	char *charset;
	int flags;			/* FLAG_USE_SSL etc, applied to the network */
};

static const struct defaultserver def[] =
{
	/* Every entry here was checked by connecting to it. TLS is used
	 * wherever the network answers on 6697; the three at the end have no
	 * TLS port at all, so they are plaintext or nothing. Networks that no
	 * longer answer are not listed. */

	{"Libera.Chat",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.libera.chat/6697"},

	{"OFTC",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.oftc.net/6697"},

	/* irc.efnet.org has no TLS port; these do. */
	{"EFnet",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.efnet.nl/6697"},
	{0,			"irc.choopa.net/6697"},

	{"IRCnet",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.ircnet.ca/6697"},

	{"DALnet",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.dal.net/6697"},

	{"Rizon",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.rizon.net/6697"},

	{"Snoonet",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.snoonet.org/6697"},

	{"IRCHighWay",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.irchighway.net/6697"},

	{"hackint",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.hackint.org/6697"},

	{"tilde.chat",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.tilde.chat/6697"},

	{"GeekShed",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.geekshed.net/6697"},

	{"EsperNet",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.esper.net/6697"},

	{"AnonOps",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.anonops.com/6697"},

	{"SpotChat",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.spotchat.org/6697"},

	{"2600net",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.2600.net/6697"},

	{"SwiftIRC",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.swiftirc.net/6697"},

	{"DarkScience",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.darkscience.net/6697"},

	{"euIRC",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.euirc.net/6697"},

	{"ChatSpike",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.chatspike.net/6697"},

	{"Abjects",	0, 0, 0, FLAG_USE_SSL},
	{0,			"irc.abjects.us/6697"},

	/* No TLS port is offered by these. */

	{"UnderNet",	0},
	{0,			"us.undernet.org"},
	{0,			"eu.undernet.org"},
	{0,			"irc.undernet.org"},

	{"QuakeNet",	0},
	{0,			"irc.quakenet.org"},

	{"GameSurge",	0},
	{0,			"irc.gamesurge.net"},

	{0,0}
};

GSList *network_list = 0;


void
servlist_connect (session *sess, ircnet *net, gboolean join)
{
	ircserver *ircserv;
	GSList *list;
	char *port;
	server *serv;

	if (!sess)
		sess = new_ircwindow (NULL, NULL, SESS_SERVER, TRUE);

	serv = sess->server;

	/* connect to the currently selected Server-row */
	list = g_slist_nth (net->servlist, net->selected);
	if (!list)
		list = net->servlist;
	if (!list)
		return;
	ircserv = list->data;

	/* incase a protocol switch is added to the servlist gui */
	server_fill_her_up (sess->server);

	if (join)
	{
		sess->willjoinchannel[0] = 0;

		if (net->autojoin)
		{
			if (serv->autojoin)
				free (serv->autojoin);
			serv->autojoin = strdup (net->autojoin);
		}
	}

	serv->password[0] = 0;
	if (net->pass)
		safe_strcpy (serv->password, net->pass, sizeof (serv->password));

	if (net->flags & FLAG_USE_GLOBAL)
	{
		strcpy (serv->nick, prefs.nick1);
	} else
	{
		if (net->nick)
			strcpy (serv->nick, net->nick);
	}

	serv->dont_use_proxy = (net->flags & FLAG_USE_PROXY) ? FALSE : TRUE;

	/* Cleared here as well as set, so a reconnect never starts out thinking
	 * an exchange from the previous attempt is still running. */
	serv->use_sasl = (net->flags & FLAG_USE_SASL) ? TRUE : FALSE;
	serv->sasl_waiting = FALSE;

#ifdef USE_OPENSSL
	serv->use_ssl = (net->flags & FLAG_USE_SSL) ? TRUE : FALSE;
	serv->accept_invalid_cert =
		(net->flags & FLAG_ALLOW_INVALID) ? TRUE : FALSE;
#endif

	serv->network = net;

	port = strrchr (ircserv->hostname, '/');
	if (port)
	{
		*port = 0;

		/* support "+port" to indicate SSL (like mIRC does) */
		if (port[1] == '+')
		{
#ifdef USE_OPENSSL
			serv->use_ssl = TRUE;
#endif
			serv->connect (serv, ircserv->hostname, atoi (port + 2), FALSE);
		} else
		{
			serv->connect (serv, ircserv->hostname, atoi (port + 1), FALSE);
		}

		*port = '/';
	} else
		serv->connect (serv, ircserv->hostname, -1, FALSE);

	server_set_encoding (serv, net->encoding);
}

int
servlist_connect_by_netname (session *sess, char *network, gboolean join)
{
	ircnet *net;
	GSList *list = network_list;

	while (list)
	{
		net = list->data;

		if (strcasecmp (net->name, network) == 0)
		{
			servlist_connect (sess, net, join);
			return 1;
		}

		list = list->next;
	}

	return 0;
}

int
servlist_have_auto (void)
{
	GSList *list = network_list;
	ircnet *net;

	while (list)
	{
		net = list->data;

		if (net->flags & FLAG_AUTO_CONNECT)
			return 1;

		list = list->next;
	}

	return 0;
}

int
servlist_auto_connect (session *sess)
{
	GSList *list = network_list;
	ircnet *net;
	int ret = 0;

	while (list)
	{
		net = list->data;

		if (net->flags & FLAG_AUTO_CONNECT)
		{
			servlist_connect (sess, net, TRUE);
			ret = 1;
		}

		list = list->next;
	}

	return ret;
}

static gint
servlist_cycle_cb (server *serv)
{
	if (serv->network)
	{
		PrintTextf (serv->server_session,
			_("Cycling to next server in %s...\n"), ((ircnet *)serv->network)->name);
		servlist_connect (serv->server_session, serv->network, TRUE);
	}

	return 0;
}

int
servlist_cycle (server *serv)
{
	ircnet *net;
	int max, del;

	net = serv->network;
	if (net)
	{
		max = g_slist_length (net->servlist);
		if (max > 0)
		{
			/* try the next server, if that option is on */
			if (net->flags & FLAG_CYCLE)
			{
				net->selected++;
				if (net->selected >= max)
					net->selected = 0;
			}

			del = prefs.recon_delay * 1000;
			if (del < 1000)
				del = 500;				  /* so it doesn't block the gui */

			if (del)
				serv->recondelay_tag = fe_timeout_add (del, (void *)servlist_cycle_cb, serv);
			else
				servlist_connect (serv->server_session, net, TRUE);

			return TRUE;
		}
	}

	return FALSE;
}

ircserver *
servlist_server_find (ircnet *net, char *name, int *pos)
{
	GSList *list = net->servlist;
	ircserver *serv;
	int i = 0;

	while (list)
	{
		serv = list->data;
		if (strcmp (serv->hostname, name) == 0)
		{
			if (pos)
				*pos = i;
			return serv;
		}
		i++;
		list = list->next;
	}

	return NULL;
}

/* find a network (e.g. (ircnet *) to "FreeNode") from a hostname
   (e.g. "irc.eu.freenode.net") */

ircnet *
servlist_net_find_from_server (char *server_name)
{
	GSList *list = network_list;
	GSList *slist;
	ircnet *net;
	ircserver *serv;

	while (list)
	{
		net = list->data;

		slist = net->servlist;
		while (slist)
		{
			serv = slist->data;
			if (strcasecmp (serv->hostname, server_name) == 0)
				return net;
			slist = slist->next;
		}

		list = list->next;
	}

	return NULL;
}

ircnet *
servlist_net_find (char *name, int *pos, int (*cmpfunc) (const char *, const char *))
{
	GSList *list = network_list;
	ircnet *net;
	int i = 0;

	while (list)
	{
		net = list->data;
		if (cmpfunc (net->name, name) == 0)
		{
			if (pos)
				*pos = i;
			return net;
		}
		i++;
		list = list->next;
	}

	return NULL;
}

ircserver *
servlist_server_add (ircnet *net, char *name)
{
	ircserver *serv;

	serv = malloc (sizeof (ircserver));
	memset (serv, 0, sizeof (ircserver));
	serv->hostname = strdup (name);

	net->servlist = g_slist_append (net->servlist, serv);

	return serv;
}

void
servlist_server_remove (ircnet *net, ircserver *serv)
{
	free (serv->hostname);
	free (serv);
	net->servlist = g_slist_remove (net->servlist, serv);
}

static void
servlist_server_remove_all (ircnet *net)
{
	ircserver *serv;

	while (net->servlist)
	{
		serv = net->servlist->data;
		servlist_server_remove (net, serv);
	}
}

static void
free_and_clear (char *str)
{
	if (str)
	{
		char *orig = str;
		while (*str)
			*str++ = 0;
		free (orig);
	}
}

/* executed on exit: Clear any password strings */

void
servlist_cleanup (void)
{
	GSList *list;
	ircnet *net;

	for (list = network_list; list; list = list->next)
	{
		net = list->data;
		free_and_clear (net->pass);
		free_and_clear (net->nickserv);
	}
}

void
servlist_net_remove (ircnet *net)
{
	GSList *list;
	server *serv;

	servlist_server_remove_all (net);
	network_list = g_slist_remove (network_list, net);

	if (net->nick)
		free (net->nick);
	if (net->nick2)
		free (net->nick2);
	if (net->user)
		free (net->user);
	if (net->real)
		free (net->real);
	free_and_clear (net->pass);
	if (net->autojoin)
		free (net->autojoin);
	if (net->command)
		free (net->command);
	free_and_clear (net->nickserv);
	if (net->comment)
		free (net->comment);
	if (net->encoding)
		free (net->encoding);
	free (net->name);
	free (net);

	/* for safety */
	list = serv_list;
	while (list)
	{
		serv = list->data;
		if (serv->network == net)
			serv->network = NULL;
		list = list->next;
	}
}

ircnet *
servlist_net_add (char *name, char *comment, int prepend)
{
	ircnet *net;

	net = malloc (sizeof (ircnet));
	memset (net, 0, sizeof (ircnet));
	net->name = strdup (name);
/*	net->comment = strdup (comment);*/
	net->flags = FLAG_CYCLE | FLAG_USE_GLOBAL | FLAG_USE_PROXY;

	if (prepend)
		network_list = g_slist_prepend (network_list, net);
	else
		network_list = g_slist_append (network_list, net);

	return net;
}

static void
servlist_load_defaults (void)
{
	int i = 0, j = 0;
	ircnet *net = NULL;

	while (1)
	{
		if (def[i].network)
		{
			net = servlist_net_add (def[i].network, def[i].host, FALSE);
			net->flags |= def[i].flags;
			net->encoding = strdup ("IRC (Latin/Unicode Hybrid)");
			if (def[i].channel)
				net->autojoin = strdup (def[i].channel);
			if (def[i].charset)
			{
				free (net->encoding);
				net->encoding = strdup (def[i].charset);
			}
			if (!strcmp (def[i].network, "Libera.Chat"))
				prefs.slist_select = j;
			j++;
		} else
		{
			servlist_server_add (net, def[i].host);
			if (!def[i+1].host && !def[i+1].network)
				break;
		}
		i++;
	}
}

static int
servlist_load (void)
{
	FILE *fp;
	char buf[2048];
	size_t len;
	char *tmp;
	ircnet *net = NULL;

	fp = xchat_fopen_file ("servlist_.conf", "r", 0);
	if (!fp)
		return FALSE;

	while (fgets (buf, sizeof (buf) - 2, fp))
	{
		len = strlen (buf);
		buf[len] = 0;
		buf[len-1] = 0;	/* remove the trailing \n */
		if (net)
		{
			switch (buf[0])
			{
			case 'I':
				net->nick = strdup (buf + 2);
				break;
			case 'i':
				net->nick2 = strdup (buf + 2);
				break;
			case 'U':
				net->user = strdup (buf + 2);
				break;
			case 'R':
				net->real = strdup (buf + 2);
				break;
			case 'P':
				/* An older configuration still holding the secret. It
				 * replaces whatever the keychain had and moves there on
				 * the next save. */
				free (net->pass);
				net->pass = strdup (buf + 2);
				break;
			case 'J':
				net->autojoin = strdup (buf + 2);
				break;
			case 'C':
				if (net->command)
				{
					/* concat extra commands with a \n separator */
					tmp = net->command;
					net->command = malloc (strlen (tmp) + strlen (buf + 2) + 2);
					strcpy (net->command, tmp);
					strcat (net->command, "\n");
					strcat (net->command, buf + 2);
					free (tmp);
				} else
					net->command = strdup (buf + 2);
				break;
			case 'F':
				net->flags = atoi (buf + 2);
				break;
			case 'D':
				net->selected = atoi (buf + 2);
				break;
			case 'E':
				net->encoding = strdup (buf + 2);
				break;
			case 'S':	/* new server/hostname for this network */
				servlist_server_add (net, buf + 2);
				break;
			case 'B':
				free (net->nickserv);
				net->nickserv = strdup (buf + 2);
				break;
			}
		}
		if (buf[0] == 'N')
		{
			net = servlist_net_add (buf + 2, /* comment */ NULL, FALSE);

			/* Older configurations kept these in the file itself; those
			 * are read below and moved across on the next save. */
			if (net)
			{
				net->pass = xa_keychain_get (net->name, "server");
				net->nickserv = xa_keychain_get (net->name, "nickserv");
			}
		}
	}
	fclose (fp);

	return TRUE;
}

void
servlist_init (void)
{
	if (!network_list)
		if (!servlist_load ())
			servlist_load_defaults ();
}

/* check if a charset is known by Iconv */
int
servlist_check_encoding (char *charset)
{
	GIConv gic;
	char *c;

	c = strchr (charset, ' ');
	if (c)
		c[0] = 0;

	if (!strcasecmp (charset, "IRC")) /* special case */
	{
		if (c)
			c[0] = ' ';
		return TRUE;
	}

	gic = g_iconv_open (charset, "UTF-8");

	if (c)
		c[0] = ' ';

	if (gic != (GIConv)-1)
	{
		g_iconv_close (gic);
		return TRUE;
	}

	return FALSE;
}

static int
servlist_write_ccmd (char *str, void *fp)
{
	return fprintf (fp, "C=%s\n", (str[0] == '/') ? str + 1 : str);
}


int
servlist_save (void)
{
	FILE *fp;
	char buf[256];
	ircnet *net;
	ircserver *serv;
	GSList *list;
	GSList *hlist;
#ifndef WIN32
	int first = FALSE;

	snprintf (buf, sizeof (buf), "%s/servlist_.conf", get_xdir_fs ());
	if (access (buf, F_OK) != 0)
		first = TRUE;
#endif

	fp = xchat_fopen_file ("servlist_.conf", "w", 0);
	if (!fp)
		return FALSE;

#ifndef WIN32
	if (first)
		chmod (buf, 0600);
#endif
	fprintf (fp, "v="PACKAGE_VERSION"\n\n");

	list = network_list;
	while (list)
	{
		net = list->data;

		fprintf (fp, "N=%s\n", net->name);
		if (net->nick)
			fprintf (fp, "I=%s\n", net->nick);
		if (net->nick2)
			fprintf (fp, "i=%s\n", net->nick2);
		if (net->user)
			fprintf (fp, "U=%s\n", net->user);
		if (net->real)
			fprintf (fp, "R=%s\n", net->real);
		/* Secrets go to the keychain rather than into this file. Setting
		 * them unconditionally also clears an entry the user emptied. */
		xa_keychain_set (net->name, "server", net->pass);
		xa_keychain_set (net->name, "nickserv", net->nickserv);

		if (net->autojoin)
			fprintf (fp, "J=%s\n", net->autojoin);
		if (net->encoding && strcasecmp (net->encoding, "System") &&
			 strcasecmp (net->encoding, "System default"))
		{
			fprintf (fp, "E=%s\n", net->encoding);
			if (!servlist_check_encoding (net->encoding))
			{
				snprintf (buf, sizeof (buf), _("Warning: \"%s\" character set is unknown. No conversion will be applied for network %s."),
							 net->encoding, net->name);
				fe_message (buf, FE_MSG_WARN);
			}
		}

		if (net->command)
			token_foreach (net->command, '\n', servlist_write_ccmd, fp);

		fprintf (fp, "F=%d\nD=%d\n", net->flags, net->selected);

		hlist = net->servlist;
		while (hlist)
		{
			serv = hlist->data;
			fprintf (fp, "S=%s\n", serv->hostname);
			hlist = hlist->next;
		}

		if (fprintf (fp, "\n") < 1)
		{
			fclose (fp);
			return FALSE;
		}

		list = list->next;
	}

	fclose (fp);
	return TRUE;
}

static void
joinlist_free1 (GSList *list)
{
	GSList *head = list;

	for (; list; list = list->next)
		g_free (list->data);
	g_slist_free (head);
}

void
joinlist_free (GSList *channels, GSList *keys)
{
	joinlist_free1 (channels);
	joinlist_free1 (keys);
}

gboolean
joinlist_is_in_list (server *serv, char *channel)
{
	GSList *channels, *keys;
	GSList *list;

	if (!serv->network || !((ircnet *)serv->network)->autojoin)
		return FALSE;

	joinlist_split (((ircnet *)serv->network)->autojoin, &channels, &keys);

	for (list = channels; list; list = list->next)
	{
		if (serv->p_cmp (list->data, channel) == 0)
			return TRUE;
	}

	joinlist_free (channels, keys);

	return FALSE;
}

gchar *
joinlist_merge (GSList *channels, GSList *keys)
{
	GString *out = g_string_new (NULL);
	GSList *list;
	int i, j;

	for (; channels; channels = channels->next)
	{
		g_string_append (out, channels->data);

		if (channels->next)
			g_string_append_c (out, ',');
	}

	/* count number of REAL keys */
	for (i = 0, list = keys; list; list = list->next)
		if (list->data)
			i++;

	if (i > 0)
	{
		g_string_append_c (out, ' ');

		for (j = 0; keys; keys = keys->next)
		{
			if (keys->data)
			{
				g_string_append (out, keys->data);
				j++;
				if (j == i)
					break;
			}

			if (keys->next)
				g_string_append_c (out, ',');
		}
	}

	return g_string_free (out, FALSE);
}

void
joinlist_split (char *autojoin, GSList **channels, GSList **keys)
{
	char *parta, *partb;
	char *chan, *key;
	size_t len;

	*channels = NULL;
	*keys = NULL;

	/* after the first space, the keys begin */
	parta = autojoin;
	partb = strchr (autojoin, ' ');
	if (partb)
		partb++;

	while (1)
	{
		chan = parta;
		key = partb;

		if (1)
		{
			while (parta[0] != 0 && parta[0] != ',' && parta[0] != ' ')
			{
				parta++;
			}
		}

		if (partb)
		{
			while (partb[0] != 0 && partb[0] != ',' && partb[0] != ' ')
			{
				partb++;
			}
		}

		len = parta - chan;
		if (len < 1)
			break;
		*channels = g_slist_append (*channels, g_strndup (chan, len));

		len = partb - key;
		*keys = g_slist_append (*keys, len ? g_strndup (key, len) : NULL);

		if (parta[0] == ' ' || parta[0] == 0)
			break;
		parta++;

		if (partb)
		{
			if (partb[0] == 0 || partb[0] == ' ')
				partb = NULL;	/* no more keys, but maybe more channels? */
			else
				partb++;
		}
	}

#if 0
	GSList *lista, *listb;
	int i;

	printf("-----\n");
	i = 0;
	lista = *channels;
	listb = *keys;
	while (lista)
	{
		printf("%d. |%s| |%s|\n", i, lista->data, listb->data);
		i++;
		lista = lista->next;
		listb = listb->next;
	}
	printf("-----\n\n");
#endif
}


