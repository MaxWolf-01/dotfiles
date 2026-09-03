/*
 * Vencord, a Discord client mod
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import { ConnectSrc, CspPolicies } from "@main/csp";

// Vencord rewrites Discord's content-security policy from this allowlist;
// without the entry the renderer's heartbeat request is dropped silently.
CspPolicies["api.wakatime.com"] = ConnectSrc;
