# The Living Grimoire: implementation decisions

The approved master brief is the product scope. All 254 Appendix A entries must be mapped. Built-in templates are immutable bundled content; activation creates a user-owned copy. No obligations or fictional completions are silently seeded.

Primary navigation is Today, Quests, Grimoire, Invocations, Chronicle. Today opens with compact date/actions and relevant daily work, then focus and horizon. Consequential deadlines across cycles remain reachable. Original Sanctuary, Stories, constellation, library and relic flows remain accessible. Fantasy/plain presentation changes labels, not stored content or semantics.

The foundation extends the existing persistence generation with `AppData.grimoire`, schema 2. Old arrays remain unchanged. The new scheduling engine owns occurrence identities and action records; views derive progress from those records. Ritual steps and smaller versions never create duplicate full completions. Goals distinguish action evidence from outcomes. New practice/goal/asset/Arcana changes use explicit durable transactions.

Recurrence uses calendar arithmetic with injected time/time zone. Monthly unavailable days clamp to the last valid day; annual February 29 proposes February 28. Quotas use one period with distinct session identities. Optional daily work renews without active debt; consequential obligations persist individually. Future edits preserve history and use explicit effective dates.

No new account, paid integration, runtime AI, cloud sync, astrology service, contact scraping or push service is added. Local reminders are optional, permission-dependent and bounded by platform/host capability. The app remains usable with notifications denied or unsupported.

Existing identity is extended using the original theme tokens, readable cards, native Liquid Glass and finite shader effects. Art is not a prerequisite for core controls. Sound is opt-in; accessibility preferences take precedence.
