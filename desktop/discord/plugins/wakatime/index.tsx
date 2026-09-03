/*
 * Vencord, a Discord client mod
 * Copyright (c) 2024 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Derived from wakatime/vencord-wakatime (de045a0). Upstream sends a heartbeat
 * on a two-minute timer regardless of focus; this version sends on activity.
 */

import { definePluginSettings } from "@api/Settings";
import definePlugin, { OptionType } from "@utils/types";

// WakaTime merges heartbeats closer than the account's keystroke timeout into
// one duration, so one heartbeat per interval is enough while active.
const HEARTBEAT_INTERVAL_MS = 120_000;

const settings = definePluginSettings({
    apiKey: {
        type: OptionType.STRING,
        description: "API Key for WakaTime",
        default: "",
        isValid: (value: string) => {
            if (!value?.startsWith("waka_")) return "Invalid Key: Please obtain your API Key from WakaTime";
            return true;
        },
    },
    debug: {
        type: OptionType.BOOLEAN,
        description: "Enable debug mode",
        default: false,
    },
    machineName: {
        type: OptionType.STRING,
        description: "Machine name",
        default: "Vencord User",
    },
    projectName: {
        type: OptionType.STRING,
        description: "Project Name",
        default: "Discord",
    },
});

async function sendHeartbeat() {
    const { debug, apiKey, machineName, projectName } = settings.store;

    if (!apiKey) return;

    if (debug) console.log("Sending heartbeat to WakaTime API.");

    const body = JSON.stringify({
        time: Date.now() / 1000,
        entity: "Discord",
        type: "app",
        project: projectName ?? "Discord",
        plugin: "vencord/version discord-wakatime/v0.0.1",
    });

    const res = await fetch("https://api.wakatime.com/api/v1/users/current/heartbeats", {
        method: "POST",
        body,
        headers: {
            Authorization: `Basic ${apiKey}`,
            "Content-Type": "application/json",
            ...(machineName ? { "X-Machine-Name": machineName } : {}),
        },
    });

    if (res.status !== 200 && res.status !== 201) console.warn(`WakaTime API Error ${res.status}: ${await res.text()}`);
}

export default definePlugin({
    name: "Wakatime",
    description: "Automatic time tracking via WakaTime: a heartbeat on focus, input, and while the window stays focused",
    authors: [
        { name: "Neon", id: 566766267046821888n },
        { name: "thororen", id: 848339671629299742n },
    ],
    settings,

    lastSent: 0,
    interval: null as ReturnType<typeof setInterval> | null,

    onActivity() {
        if (Date.now() - this.lastSent < HEARTBEAT_INTERVAL_MS) return;
        this.lastSent = Date.now();
        sendHeartbeat();
    },

    start() {
        this.onActivity = this.onActivity.bind(this);
        window.addEventListener("focus", this.onActivity);
        document.addEventListener("keydown", this.onActivity, true);
        document.addEventListener("mousedown", this.onActivity, true);
        this.interval = setInterval(() => {
            if (document.hasFocus()) this.onActivity();
        }, HEARTBEAT_INTERVAL_MS);
    },

    stop() {
        window.removeEventListener("focus", this.onActivity);
        document.removeEventListener("keydown", this.onActivity, true);
        document.removeEventListener("mousedown", this.onActivity, true);
        if (this.interval) clearInterval(this.interval);
    },
});
