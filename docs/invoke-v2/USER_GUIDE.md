# Invoke 2.0 user guide

Invoke organizes the practices you choose, the direction they serve and what you actually observe. It works with a local library on your iPhone. The public GitHub repository does not contain your writing or photos.

The five tabs are **Today, Quests, Grimoire, Invocations and Chronicle**. Settings is the sliders button at the top of Today. New installations use Astral Theatre; an existing installation keeps its saved appearance.

## Update through LiveContainer without losing your collection

The intended host is the owner’s **iOS 27 / LiveContainer 3.8.10** environment. A simulator build is separate from a successful physical-device test. Check the release’s [acceptance record](ACCEPTANCE.md) and [LiveContainer notes](LIVECONTAINER.md) for what was actually verified.

1. Open your existing Invoke. In Settings, choose **Export complete backup**, then save the .invoke file somewhere outside the Invoke/LiveContainer data container in Files. Keep this pre-upgrade file. It includes private writing and referenced photographs.
2. Get Invoke.ipa from the [Invoke release page](https://github.com/Mostlybonezz/Invoke/releases). Check the version shown on the release and the downloaded asset; do not treat a source archive as an installable IPA.
3. Import/update Invoke in the **same LiveContainer installation**, retaining its existing Invoke data container. The app’s bundle identifier remains app.invoke.personal. Preserve the old container if the host offers a container choice; deleting and recreating it would make the app appear empty.
4. Launch Invoke. Existing users see a brief 2.0 introduction and **Continue to Today**. Confirm your stories, scenes, beliefs, original rituals/logs, relic photographs and theme are present using the locations below.
5. Export another complete backup after checking the upgrade. Keep both exports until you are satisfied with the update.

LiveContainer separates app bundles from their data containers. Its official [app settings guide](https://livecontainer.github.io/docs/guides/app-settings) describes the container list and **Select Unused Container** for attaching an existing unused private container. If Invoke opens as a new empty installation, inspect which container is attached before creating replacement data. Do not use unused-data cleanup as an update step: it deletes unreferenced data folders. See [LiveContainer data management](https://livecontainer.github.io/docs/guides/data-management).

You can also add this release source in a compatible LiveContainer source manager:

    https://github.com/Mostlybonezz/Invoke/releases/latest/download/source.json

The IPA is for LiveContainer or a compatible signing/install tool. Downloading it in Safari does not by itself install an App Store-signed app.

## Find everything from the previous version

| Familiar feature | Location in 2.0 |
| --- | --- |
| Sanctuary and its constellation | Today → top-left star button, **Story sanctuary and constellation** |
| Story authoring, chapters and scenes | Invocations → top-left book button, **Stories, scenes and constellations** |
| Original manifestations, beliefs and rituals | Grimoire → top-left **Original collection** menu → **Original Grimoire**; also linked near the top of Invocations |
| Original ritual performance logs and reflections | Their original pages; relevant entries also appear in Chronicle |
| Relics, photographs, workshop, dedication and PDF sharing | Grimoire → top-left **Original collection** menu → **Relic Cabinet** |
| Theme, glass and shader customization | Today → Settings → **Appearance** |
| Complete backups | Today → Settings → **Export complete backup** / **Restore from backup** |

The star, book and Original collection controls stay in the navigation bar as collections grow. To use the constellation, open the original Sanctuary, tap its constellation, then a labeled scene star. The readable scene list and chapter controls remain available.

Links between new and old records are optional. In a practice’s **Connections**, choose an original ritual or scene. An Invocation has **Links to your original collection** for a story or manifestation; Arcana’s **Origin and method** can link an original belief. Linking preserves the original writing and history and does not create a new completion.

## Start with only what you want

Fresh setup lets you choose domains, responsibilities and desired development, then approve a small starting set. You may choose no templates or **Skip setup and open Today**. Existing users are not required to repeat this setup.

Revisit these choices through Settings → **Calendar, reminders & restoration** → **Review applicable domains and starting practices**. Selecting a responsibility does not activate every template in that area.

For a practice from the full library:

1. Open **Grimoire** and choose **Codex library** from the shelf menu.
2. Choose a discipline or search by the ordinary name, fantasy name, instructions or source ID.
3. Open an entry. Read its applicability, instructions, completion scope and source disclosure.
4. Choose **Configure this practice**. Review the title, schedule, importance and any real instructions/dates you need to supply. Save to activate your copy.

All 254 source entries are represented by 252 canonical templates/references. Some entries consolidate overlapping source lines; eight are references and do not activate as tasks. Actual clinical, manufacturer, product, legal and expiry schedules must come from your relevant instructions. Unknown dates remain unset.

The Codex is a suggestion library. Your saved copy belongs to you and remains in **My practices** when bundled content changes. If a template already has a personalized copy, its preview links that copy and offers **Create another customized copy**. Review whether it represents a genuinely separate practice before saving.

To make a custom practice, use Today’s plus button, Quests’ plus button or Grimoire → **Add to Grimoire** → **Custom practice**. Add your own wording, optional steps and smaller version. This reusable definition belongs to My practices; it does not modify the bundled Codex or invent prior completions.

## Use Today and Quests

**Needs attention** exposes consequential deadlines and critical work across cycles. Expand it to see all matching obligations. The daily progress text counts planned daily practices, not a percentage of your life. A chosen focus and a short horizon sit below the actions.

In **Quests**, choose Today, Week, Month, Quarter, Year or Custom. Filters cover discipline, importance, purpose, status and recurrence. Search matches ordinary and fantasy wording. Definitions remain available even when they are unscheduled, paused or waiting for an event.

Importance is your choice:

- **Critical**: a consequential/time-sensitive obligation; explain why where useful.
- **Core**: a central chosen commitment.
- **Supporting**: useful upkeep or progress with flexibility.
- **Optional**: additional exploration or activity.

Frequency and importance are separate. A yearly obligation can deserve attention before an optional daily practice.

## Record a ritual, partial work or correction

1. Open an occurrence from Today, Quests or the practice page.
2. Choose **Begin / resume ritual** when you want a session. Check the steps you actually perform. Step progress is saved independently of full completion.
3. Add notes or an optional measurement. The elapsed timer is optional and never completes the work for you.
4. Choose **Record full ritual** when every required step was performed, or **Mark complete** for a practice without steps. Use **Save partial progress & notes** or **Record smaller version** when that better describes what happened.
5. For a quota, **Begin a separate session** represents another genuine session in the same period. Repeating a completion tap does not create another session.

Use **Record an earlier action** to enter its actual time. The action retains a separate recorded time and its occurrence’s time zone.

**Skip this occurrence** is an explicit skip, not completion. **Reschedule** defers that occurrence’s availability and keeps its original hard deadline. **Snooze reminder for one hour** changes only the notification time.

To correct an action, use its **Undo** button or open it in Chronicle and choose **Undo this record**. The original remains visible with an Undone label and a dated Correction; counts are recalculated. An opportunity with no record is different from a skip or a failure.

On the practice page, **Edit future practice**, **Pause practice** and **Archive practice** affect future use without deleting recorded history. Review the effective date and generated schedule preview before saving an edit. Restore an archived record when you want it active again.

## Calendar policies to know

| Choice | Meaning |
| --- | --- |
| Unscheduled | One available practice without an invented due date |
| One-time date | One chosen occurrence, with an optional separate hard deadline |
| Daily / selected weekdays | Calendar-day opportunities, with optional distinct daily time slots |
| Weekly | One flexible weekly window |
| Sessions per week | One period with a chosen number of genuine sessions |
| Monthly | A numbered day, month’s last day, or selected weekday occurrence |
| Quarterly | Every three calendar months from the anchor, or a labeled calendar-quarter window |
| Semiannual / annual | Calendar-month/year recurrence; not fixed 180/365-day approximations |
| After completion | Next opportunity follows the last actual full completion; skipping does not advance it |
| After an event | A matching event must be recorded through Quests → **Record event** |
| Condition review | Inspect on a chosen schedule; create repair/replacement work only when the observed condition warrants it |
| Custom calendar interval | Count calendar days, weeks, months or years from the original anchor |

A numbered date missing from a month uses that month’s last valid day. An annual February 29 uses February 28 in non-leap years. An absent fifth weekday is skipped. Daylight-saving gaps use the next valid local time; a repeated wall time occurs once.

**Renew without debt** lets ordinary daily practice renew without accumulating an endless active backlog. **Keep until resolved** retains distinct obligations. **Flexible window** suits period-based work. **Inspect condition** keeps inspection separate from replacement.

Settings → **Calendar, reminders & restoration** contains the week start and home/travel time-zone policy. Saved occurrences and actions retain their original time zone. Review the preview when changing calendar behavior. Editing an app date does not alter an external legal, financial or other real-world deadline.

## Shape an Invocation

Open **Invocations** → plus. Work through name/intention, meaning, optional evidence, influence, obstacles, counterspells/practical responses, milestones and review date. A direction can be exploratory and need no numerical target.

After saving, open the Invocation and choose **Add a linked quest or ritual**. Completed linked actions are counted as action history. **Record an observation** captures what actually changed, independently. Milestones and status are your explicit records; checking off effort does not automatically establish the desired outcome.

If an observation needs fixing, choose **Correct observation** on its card. Saving updates that same observation and keeps the earlier value in Chronicle’s change history. It does not add another observation or credit another action.

## Use the other Grimoire shelves

Use **Add to Grimoire** to create these records, then choose their shelf to find them again:

- **Spells & methods**: a named technique, method, source and notes. Link it from a practice’s Connections.
- **Enabling arrangements**: an Enchantment records what supports you, its status and your establishment evidence. Choose a maintenance practice and optional review date. An automatic payment or backup is not externally verified by Invoke.
- **Assets & supplies**: record only useful possessions/consumables, responsibility, care instructions, condition, known dates, quantities and optional replacement reserve. The reserve is simply your entered target minus your entered reserved amount.
- **Arcana & beliefs**: preserve origin/source, method, expectation, observation, interpretation, alternatives and your next decision. Belief positions are Exploring, Practicing, Personally Accepted, Questioning and Archived.
- **Echoes & comparisons**: keep both sources, similarities, meaningful differences, original context, historical evidence, interpretation, questions and changes of view.

For an asset, open its page → **Record a condition observation**. Serviceable items can remain in use. A warranted repair/replacement/replenishment can have an explicitly selected follow-up quest. A purchase date alone does not generate disposal work.

For Bonds, choose **Tend & widen the circle** in the Codex shelf. Maintenance, Moderate and Active growth are editable planning suggestions. A pace selection activates nothing: open each proposed practice and review/save it. A recorded invitation describes your action; another person’s response is an independent observation.

Archived specialty records remain available through **Show archived records**. Restore one to edit it. Their existing history and links are retained.

## Read your Chronicle

Chronicle combines actions and corrections, reflections, Arcana, Echoes, inspections, Invocation observations/milestones, recorded events and preserved revisions. Original ritual logs and reflections remain linked to their sources.

Search text or open **Dates and record types**. Choose a date range/type; optionally include opportunities with no record. That optional calendar view is bounded to a year and does not invent activity. Use **Show 100 more** for further matching records.

The writing button records a short reflection. This is a private observation, not a task completion. You can find it later in Chronicle or Grimoire → Arcana.

## Appearance, restoration and reminders

Settings → **Appearance** keeps Astral Theatre, Velvet Observatory and Ink & Omen, plus system/tinted/solid surfaces and the existing shader controls. Use the effect preview to choose a comfortable intensity. System accessibility preferences take precedence.

Settings → **Calendar, reminders & restoration** has fantasy/plain wording, motion, optional recognition, chosen focus and **Restoration Mode**. Restoration Mode foregrounds your chosen essentials and consequential deadlines; other work remains in Quests.

For notifications, choose **Allow notifications on this device**, enable local reminders, and set a reminder time on the relevant practice. Private previews are the default; sound is optional. Quiet hours move delivery, not deadlines. The queue is bounded and refreshes when Invoke is used; iOS and LiveContainer control actual delivery.

If Files or notifications fail only inside the host, LiveContainer’s official [guest-app guide](https://livecontainer.github.io/docs/faq/using-guest-apps) describes holding the Invoke card → Settings → **Fix File Picker** or **Fix Local Notifications**. Invoke remains usable with notifications denied.

## Backups, import and recovery

Export through Settings → **Export complete backup**. The file contains sensitive personal writing, history and images; it is not an encrypted vault. Choose where to store it. Device backups depend on your iPhone settings, and deleting the app/container can delete its local data.

**Restore from backup** first validates and previews a file:

- **Merge new records into my collection** adds new identities and keeps current records/preferences on conflicts. Inconsistent links or conflicting photographs are rejected rather than guessed.
- **Replace with this backup** restores the complete selected collection after explicit confirmation. A retained recovery copy is created first when the current collection is readable.

Where available, **Save retained recovery copy** exports the local checkpoint and **Review retained recovery copy** opens its validation preview. If local storage cannot be opened safely, use the dedicated recovery route; it preserves the existing files instead of treating empty defaults as a recovered collection.

Keep the app/container while investigating a failed upgrade. Reinstalling an older executable alone does not reverse a data-format change; use the appropriate pre-upgrade portable backup. More detail is in [Migration and recovery](MIGRATION.md).

Physical iPhone/LiveContainer launch, real notification delivery, VoiceOver and full device-performance checks must be recorded separately from simulator results in [Acceptance](ACCEPTANCE.md).
