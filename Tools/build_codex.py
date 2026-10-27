"""Build the versioned, inactive Codex library and complete source coverage map.

Input is the user-provided Appendix A, committed alongside its mapping. This is
planning content, not a clinical, legal, financial or model-specific standard.
No third-party network access or private user data is used by this generator.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/invoke-v2/CODEX_SOURCE.md'
OUTPUT = ROOT / 'Invoke/Resources/Codex.json'
COVERAGE = ROOT / 'docs/invoke-v2/CONTENT_COVERAGE.md'
COUNTS = [16, 11, 18, 11, 11, 14, 12, 12, 12, 12, 10, 13, 10, 13, 7, 22, 8, 10, 10, 10, 12]

# Concise plain-language names. Full original text is retained in each record.
TITLES = {
    'C01': 'Oral care|Personal hygiene|Sleep opportunity and quality|Food and fluids|Established medication instructions|Ordinary movement|Your training plan|Recovery and discomfort review|Meal and grocery planning|Chosen health measurements|Arrange appropriate care|Prescription supply and refills|Review health patterns|Personal preventive-care schedule|Medication review with your clinician|Keep useful health records',
    'C02': 'Hair and preferred grooming|Skin care and sun protection|Nail care|Clean grooming tools|Care for cosmetic applicators|Haircut or style maintenance|Inspect grooming equipment|Review personal-care supplies|Review your presentation|Simplify grooming routines|Store and inspect sensitive products',
    'C03': 'Sort clothing and treat stains|Air and store clothes and footwear|Laundry and clothing care|Clean and inspect footwear|Repair clothing|Inspect socks and base layers|Inspect everyday clothing|Care for knitwear|Inspect and maintain shoes|Care for accessories|Identify wardrobe gaps|Review fit and tailoring|Explore outfit combinations|Seasonal clothing transition|Inspect outerwear and boots|Update style references|Review wardrobe condition and costs|Review durable clothing purchases',
    'C04': 'Keep your sleeping area usable|Review the sleep environment|Launder sheets and pillowcases|Clean the bedroom|Care for bedding|Clean and organize bedroom storage|Inspect pillows and mattress|Check bedroom moisture and odors|Care for curtains and windows|Manufacturer-guided mattress rotation|Review bedroom repairs and support',
    'C05': 'Clean bathroom surfaces|Launder towels and bath mats|Replenish bathroom essentials|Clean reusable bathroom accessories|Maintain accessible drains and fixtures|Clean ventilation safely|Check bathroom leaks and operation|Inspect grout and sealant|Address bathroom dampness and damage|Review bathroom products and tools|Arrange bathroom repairs',
    'C06': 'Clean dishes and preparation surfaces|Store food according to appropriate guidance|Meal and grocery planning|Review leftovers and grocery needs|Clean kitchen appliances|Care for kitchen cloths and tools|Inspect pantry storage|Clean and check the refrigerator|Maintain oven and range hood|Inspect cookware and cutting tools|Clean reusable food containers|Follow water-filter and appliance instructions|Review food costs and workflow|Review kitchen repairs and storage',
    'C07': 'Remove waste and clear common areas|Reset surfaces and storage|Clean floors and dust|Clean windows and details|Clean upholstery and hard-to-reach areas|Organize household storage|Inspect furniture repairs|Deep-clean selected areas|Review stored possessions|Choose what to keep or retire|Check pests, leaks and dampness|Maintain a useful possession inventory',
    'C08': 'Smoke and carbon monoxide alarm instructions|Fire extinguisher inspection and service|Maintain ventilation filters|Dryer lint and exhaust care|Check visible leaks|Observe electrical faults safely|Inspect doors, windows and locks|Review changes in utility use|Seasonal heating and cooling care|Arrange property inspections safely|Check after storm damage|Plan responsible home repairs',
    'C09': 'Vehicle-specific tire pressure checks|Inspect tire condition|Check lights, wipers and washer supply|Check vehicle warnings and supplies|Clean your vehicle|Follow the vehicle service plan|Arrange vehicle inspection or repair|Check authoritative recall information|Record vehicle service and costs|Actual vehicle renewal deadlines|Review vehicle emergency supplies|Review transportation plans and costs',
    'C10': 'Review balances and upcoming obligations|Investigate transaction errors|Review your spending plan|Pay and verify obligations|Record chosen savings plans|Review debt and payoff progress|Review subscriptions and irregular costs|Plan replacement reserves|Compare recurring costs|Review your financial goals|Organize actual tax deadlines|Review changed financial needs',
    'C11': 'Review actual renewal deadlines|File important records|Maintain secure document access|Check identity and travel-document dates|Keep essential records|Review contracts, ownership and warranties|Update changed contact details|Review relevant legal arrangements|Attend to applicable civic notices|Plan authorized access in contingencies',
    'C12': 'Install supported software updates|Maintain important-file backups|Organize digital files and messages|Review device condition and behavior|Clean devices safely|Inspect power accessories and batteries|Review apps and subscriptions|Test a representative backup restore|Review sign-in and recovery options|Review permissions and connected accounts|Review security support and retention|Plan condition-based device changes|Keep useful device and warranty records',
    'C13': 'Prepare work schedule and equipment|Review immediate work priorities|Verify pay and payroll records|Record achievements and feedback|Review workload and working conditions|Review career direction|Complete selected or required training|Update professional records|Review actual benefit and license deadlines|Review work and longer-term goals',
    'C14': 'Make room for chosen friendships|Respond and follow up as desired|Initiate a shared activity|Reconnect with someone|Review desired contact and enjoyment|Review contact preferences and occasions|Attend a recurring social setting|Practice conversations and listening|Follow up with an acquaintance|Explore a new community|Review social access and logistics|Choose your social expansion pace|Address conflict and boundaries',
    'C15': 'Make time for chosen relationships|Coordinate household logistics|Arrange a meaningful shared experience|Review relationship commitments|Review dating or partnership intentions|Coordinate responsibilities you hold|Review shared-living arrangements',
    'C16': 'Chosen spiritual or contemplative practice|Record dreams, symbols and questions|Connect an intention with action|Observe thought, perception and choices|Study a spiritual or philosophical source|Develop a chosen technique|Explore an unfamiliar worldview|Record contradictions and questions|Revisit spiritual practice notes|Choose a focused practice|User-scheduled celestial or seasonal observance|Compare expectations and observations|Revise your personal Grimoire|Compare traditions through sources|Distinguish types of claims|Revisit a belief|Review your worldview|Choose future study|Spiritual and philosophical study areas|A meaningful practice record|Questions for comparative inquiry|Lenses for spiritual development',
    'C17': 'Protect time for enjoyment and rest|Notice your own stress and energy|Enjoy a hobby|Spend time in a preferred environment|Review stressors and recovery|Simplify excessive obligations|Seek appropriate support when needed|Review enjoyment and obligation',
    'C18': 'Practice or study a chosen skill|Save useful notes and methods|Advance a creative project|Review learning priorities|Review unfinished work and examples|Complete a chosen milestone|Consolidate and try techniques|Review learning and making|Reflect on skills developed|Archive projects and reassess interests',
    'C19': 'Inspect first-aid supplies|Plan supplies using applicable guidance|Check emergency light and power equipment|Review emergency kit condition|Maintain emergency contacts and documents|Review evacuation and communication plans|Prepare for relevant regional hazards|Learn appropriate utility-shutoff procedures|Review essential security|Update contingency plans after changes',
    'C20': 'Seasonal clothing transition|Inspect seasonal recreation equipment|Linked seasonal home and vehicle care|Care for outdoor areas you manage|Inspect seasonal storage|Your established pet-care plan|Plant and garden care|Prepare for an actual trip|Care for specialist equipment|Your dependent-care responsibilities',
    'C21': 'Review current priorities|Simplify your maintenance system|Review time and chosen objectives|Review progress across life|Reallocate attention deliberately|Revise goals and routines|Review important possessions and commitments|Prepare for foreseeable transitions|Plan the next period|Review rituals without duplicate credit|Different kinds of resources|Choose useful practice metadata',
}

# Magical titles remain paired with plain names; safety instructions stay plain.
FANTASY = {
    'C01.03': 'Keep the Quiet Hours', 'C01.07': 'Rite of Tempering',
    'C03.03': 'Renew the Vestments', 'C03.13': 'Refine Your Aspect',
    'C03.14': 'Turn the Seasonal Wardrobe', 'C04.01': 'Tend the Resting Place',
    'C06.03': 'Provision the Hearth', 'C07.02': 'Restore the Hearth',
    'C10.08': 'Keep a Reserve', 'C11.03': 'Ward the Records',
    'C12.02': 'Preserve the Archive', 'C12.08': 'Ward of Continuity',
    'C13.04': 'Gather Proof of Your Craft', 'C14.01': 'Tend the Circle',
    'C14.04': 'Renew a Thread', 'C14.07': 'Widen the Circle',
    'C14.09': 'Carry the Conversation', 'C15.03': 'Make Shared Memories',
    'C16.01': 'The Chosen Rite', 'C16.02': 'Gather the Night Pages',
    'C16.03': 'Call an Intention into Practice', 'C16.05': 'Study the Hidden Arts',
    'C16.08': 'Keep the Open Questions', 'C16.14': 'Trace an Echo',
    'C16.16': 'Revisit a Conviction', 'C16.17': 'Read Your Evolving Worldview',
    'C17.01': 'Make Room for Renewal', 'C17.03': 'Follow Delight',
    'C18.01': 'Practice the Craft', 'C18.03': 'Bring the Work Forward',
    'C18.06': 'Mark a Milestone', 'C19.06': 'Ward of Readiness',
    'C20.08': 'Prepare the Way', 'C21.01': 'Read the Present Chapter',
    'C21.02': 'Lighten the Grimoire', 'C21.09': 'Open the Next Chapter',
}
DISCIPLINES = {
    'C01': ['vitality'], 'C02': ['regalia', 'vitality'], 'C03': ['regalia'],
    'C04': ['hearth', 'vitality'], 'C05': ['hearth'], 'C06': ['hearth', 'vitality'],
    'C07': ['hearth'], 'C08': ['hearth', 'stewardship'], 'C09': ['wayfaring'],
    'C10': ['stewardship'], 'C11': ['stewardship'], 'C12': ['artifice'],
    'C13': ['craft'], 'C14': ['bonds'], 'C15': ['bonds'], 'C16': ['arcana'],
    'C17': ['renewal', 'vitality'], 'C18': ['craft'], 'C19': ['stewardship', 'hearth', 'wayfaring'],
    'C20': ['hearth', 'wayfaring'], 'C21': ['renewal', 'stewardship'],
}
DISCIPLINE_OVERRIDES = {
    'C20.01': ['regalia'], 'C20.06': ['hearth'], 'C20.07': ['hearth'],
    'C20.09': ['craft', 'wayfaring'], 'C20.10': ['bonds', 'stewardship'],
}
ALIASES = {'C01.09': 'C06.03', 'C20.01': 'C03.14'}
REFERENCE_IDS = {f'C16.{i:02d}' for i in range(19, 23)} | {'C21.10', 'C21.11', 'C21.12', 'C20.03'}
RELATED = {
    'C01.04': ['C06.03'], 'C20.03': ['C08.09', 'C09.06'],
    'C21.10': ['C21.01', 'C21.04', 'C21.07'],
}
CORE = {'C01.01', 'C01.03', 'C01.05', 'C10.04', 'C17.01'}
CONFIGURED_DATES = {'C09.10', 'C11.01', 'C11.04', 'C13.09', 'C10.11'}
PERSONAL_SCHEDULES = {'C01.05', 'C01.07', 'C01.10', 'C01.12', 'C01.14', 'C01.15', 'C02.02',
                      'C04.10', 'C06.02', 'C06.12', 'C08.01', 'C08.02', 'C08.03', 'C08.04',
                      'C08.09', 'C09.01', 'C09.04', 'C09.06', 'C19.02', 'C19.08', 'C20.04', 'C20.06', 'C20.07', 'C20.09', 'C20.10'}


def parse_source():
    text = SOURCE.read_text(encoding='utf-8')
    records, groups = {}, {}
    for group in re.finditer(r'^## (C\d{2}) — (.+?)\n(.*?)(?=^## C\d{2}|\Z)', text, re.M | re.S):
        code, title = group[1], group[2].split(' → ')[0]
        groups[code] = title
        rows = re.findall(r'^(\d+)\. \[([^\]]+)\] (.+)$', group[3], re.M)
        names = TITLES[code].split('|')
        expected = COUNTS[int(code[1:]) - 1]
        assert len(rows) == len(names) == expected, code
        for (number, cadence, body), plain in zip(rows, names):
            source_id = f'{code}.{int(number):02d}'
            assert source_id not in records
            records[source_id] = {'id': source_id, 'group': code, 'title': plain,
                                  'cadence': cadence, 'text': body, 'original': f'[{cadence}] {body}'}
    assert len(records) == sum(COUNTS) == 254
    return records, groups


def applicability(record):
    source_id, group = record['id'], record['group']
    if source_id == 'C20.06':
        return 'Only if you care for a pet; use that animal’s established care plan and relevant veterinary instructions.'
    if source_id == 'C20.07':
        return 'Only for plants or outdoor areas you actually maintain; use species, condition and product instructions.'
    if source_id in {'C20.10', 'C15.06'}:
        return 'Only for dependent-care responsibilities you actually hold; no responsibility is assigned by this template.'
    if group == 'C09':
        return 'Only for a vehicle or transport arrangement you use or maintain; configure the actual model, responsibility and dates.'
    if group == 'C08':
        return 'Only for systems you are responsible for. Distinguish tenant, owner, landlord and qualified-service responsibilities.'
    if group in {'C04', 'C05', 'C06', 'C07'}:
        return 'Choose the parts relevant to your living arrangements, equipment, access and actual household responsibility.'
    if group == 'C13':
        return 'Adapt to your actual employment, training, credentials and chosen professional direction.'
    if group in {'C14', 'C15'}:
        return 'Choose relationships, contact preferences and commitments yourself. Cadence is an editable planning preference.'
    if group == 'C16':
        return 'Choose the tradition, source, practice or question that interests you. Belief and participation are optional.'
    if source_id in PERSONAL_SCHEDULES or 'P' in record['cadence'].split('/'):
        return 'Configure this from your established plan or the relevant professional, manufacturer or product instructions.'
    return 'Activate only if useful to your own priorities and responsibilities; edit the suggested plan before saving.'


def schedule(record):
    source_id, cadence = record['id'], record['cadence']
    if source_id in REFERENCE_IDS:
        return 'reference'
    if source_id in CONFIGURED_DATES:
        return 'oneOff'
    if source_id in PERSONAL_SCHEDULES:
        return 'configured'
    if source_id == 'C01.11' or cadence.startswith('C'):
        return 'condition'
    if cadence.startswith('E'):
        return 'event'
    return {'D': 'daily', 'W': 'weekly', 'M': 'monthly', 'Q': 'quarterly',
            'S': 'semiannual', 'Y': 'annual', 'P': 'configured'}.get(cadence[:1], 'configured')


def build():
    records, groups = parse_source()
    templates = []
    for source_id, record in records.items():
        if source_id in ALIASES:
            continue
        source_ids = [source_id] + [alias for alias, target in ALIASES.items() if target == source_id]
        reference = source_id in REFERENCE_IDS
        source_records = [records[key] for key in source_ids]
        group = record['group']
        purpose = ('discovery' if group == 'C16' or source_id in {'C14.10', 'C18.07'}
                   else 'transformation' if group in {'C13', 'C18'} or source_id in {'C01.07', 'C03.13', 'C14.07', 'C14.08', 'C14.09'}
                   else 'preservation')
        tags = [groups[group]]
        if group in {'C08', 'C19'} or source_id in {'C12.02', 'C12.08', 'C12.09', 'C12.10'}:
            tags.append('ward')
        if source_id.startswith('C14.'):
            tags.append('Tend the Circle' if int(source_id[-2:]) < 7 else 'Widen the Circle')
        if purpose != 'preservation':
            tags.append('development')
        if record['cadence'].startswith('S'):
            tags.append('seasonal')
        instructions = [item['text'] for item in source_records]
        if source_id == 'C20.03':
            instructions.append('Open the linked home and vehicle practices that apply to you; do not create a second completion for the same action.')
        # The brief defines organizing suggestions; do not upgrade it to expert advice.
        review_status = ('Reference; no recurring obligation' if reference else
                         'Configure actual instructions and dates before activation' if source_id in PERSONAL_SCHEDULES | CONFIGURED_DATES else
                         'Planning suggestion; review applicability and cadence before activation')
        templates.append({
            'id': 'codex.' + source_id, 'contentVersion': 1, 'sourceIDs': source_ids,
            'sourceTexts': [item['original'] for item in source_records],
            'plainTitle': record['title'], 'fantasyTitle': FANTASY.get(source_id, record['title']),
            'instructions': instructions, 'disciplines': DISCIPLINE_OVERRIDES.get(source_id, DISCIPLINES[group]),
            'purpose': purpose, 'tags': tags,
            'applicability': applicability(record),
            'responsibleParty': ('Use the responsible household member, owner, landlord or qualified professional as appropriate; do not attempt hazardous work.' if group in {'C08', 'C09', 'C19'} else
                                 'You choose who is responsible; add only commitments you actually hold.'),
            'suggestedSchedule': schedule(record), 'cadenceDescription': record['cadence'],
            'requiresScheduleConfiguration': not reference,
            'suggestedImportance': ('core' if source_id in CORE else 'optional' if purpose == 'discovery' else 'supporting'),
            'completionCriteria': ('Read or reference this material when useful; it does not create completion credit.' if reference else
                                   'Record what you actually did or observed. Partial work and a smaller version keep their actual scope.'),
            'followOnTrigger': ('Open the existing linked practices when relevant.' if reference else
                                'Create follow-up work only when an actual observation, configured trigger, supply need or real deadline warrants it. Serviceable items can remain in use.'),
            'provenance': 'User-provided Life Maintenance Codex, Appendix A; configurable organizing suggestion.',
            'reviewStatus': review_status, 'sourceLinks': [], 'referenceOnly': reference,
            'relatedTemplateIDs': ['codex.' + ALIASES.get(key, key) for key in RELATED.get(source_id, [])],
        })
    all_ids = [source_id for template in templates for source_id in template['sourceIDs']]
    assert len(all_ids) == len(set(all_ids)) == 254
    assert set(all_ids) == set(records)
    template_ids = {template['id'] for template in templates}
    assert all(set(template['relatedTemplateIDs']) <= template_ids for template in templates)
    library = {'formatVersion': 1, 'contentVersion': 1,
               'sourceSHA256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
               'sourceEntryCount': 254, 'templates': templates}
    coverage = ['# Codex content coverage', '',
                'All 254 numbered Appendix A entries map to the reachable, inactive library below. '
                'The bundled library contains 252 canonical templates/references, including 8 reference-only records. '
                'No template activates by itself. Personalized practices are copies with stable origin IDs; a content update never overwrites them.', '',
                '## Provenance and review boundaries', '',
                'The preserved source is `CODEX_SOURCE.md`, extracted from the user-provided Invoke 2.0 brief. '
                'These are organizing suggestions. They have not been presented as reviewed clinical, financial, legal, safety or model-specific standards. '
                'The bundled records supply no fabricated citations or universal replacement ages. '
                'Exact medication, screening, product, vehicle, legal and expiry schedules require the user’s actual instructions or dates. '
                'All actionable templates require configuration/review before activation. '
                'Health and safety entries retain referral and responsible-party boundaries; the app supplies no hazardous procedures or treatment changes.', '',
                'Clothing/footwear/device care records distinguish inspection, replenishment, condition-based repair/replacement and actual labeled expiry. '
                'Bonds uses chosen contact preferences; Arcana separates sources, observation and interpretation. '
                'The complete original wording and source IDs remain searchable in every template.', '',
                '## Normalization', '',
                '- C01.09 shares the meal/grocery-planning template C06.03.',
                '- C20.01 shares the seasonal-clothing template C03.14.',
                '- C20.03 is a reference linking C08.09 and C09.06; it cannot award another completion.',
                '- C16.19–22 and C21.10–12 are reference entries, not recurring obligations.', '',
                '## Coverage', '', '| Source ID | Canonical template | Plain title | Kind |', '| --- | --- | --- | --- |']
    mapping = {source_id: template for template in templates for source_id in template['sourceIDs']}
    for source_id in records:
        template = mapping[source_id]
        kind = 'Reference' if template['referenceOnly'] else 'Practice'
        if source_id in ALIASES:
            kind += ' (consolidated)'
        coverage.append(f'| {source_id} | `{template["id"]}` | {template["plainTitle"]} | {kind} |')
    coverage += ['', '## Verification', '',
                 '`python Tools/build_codex.py --check` verifies the generated files against all 254 source lines, unique source mappings, canonical IDs and reference links. '
                 '`CodexLibraryTests` checks bundled decoding, complete coverage, search, configured schedules and error handling. '
                 'Native test execution and visual evidence are recorded in `ACCEPTANCE.md` by the release owner.', '']
    return json.dumps(library, indent=2, ensure_ascii=False) + '\n', '\n'.join(coverage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    content, coverage = build()
    for path, expected in [(OUTPUT, content), (COVERAGE, coverage)]:
        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != expected:
                raise SystemExit(f'Generated content differs: {path.relative_to(ROOT)}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(expected, encoding='utf-8', newline='\n')
    print('Codex coverage PASS: 254 source entries, 252 canonical templates/references, 8 reference-only entries.')


if __name__ == '__main__':
    main()
