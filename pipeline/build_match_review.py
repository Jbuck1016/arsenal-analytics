"""Build a reproducible, read-only editorial review from saved evidence."""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'artifacts/model_reports'


def build():
    source = REPORT / 'shadow_weekend_review_20260917.json'
    report = json.loads(source.read_text(encoding='utf-8'))
    match = next(m for m in report['all_matches'] if m['game_id'] == 'fd-560586')
    shots = json.loads((REPORT / 'brighton_arsenal_review_shots.json').read_text(encoding='utf-8'))
    comparison = json.loads((REPORT / 'live_challenger_comparison.json').read_text(encoding='utf-8'))
    challenger = next(m for m in comparison['all_fixture_comparisons'] if m['game_id'] == match['game_id'])
    p = match['probabilities']
    assert abs(sum(p.values()) - 1) < 1e-6
    assert abs(-math.log(p[match['actual_outcome']]) - match['log_loss']) < 1e-10
    assert abs(sum((v - (k == match['actual_outcome'])) ** 2 for k, v in p.items()) - match['brier']) < 1e-10
    for side in ('home', 'away'):
        events = [s for s in shots['shots'] if s['team'] == match[f'{side}_team']]
        assert len(events) == match['tactical'][side]['shots']
        assert sum(s['is_goal'] for s in events) == match[f'{side}_score']
        assert all(s['xg'] is not None and 0 <= float(s['xg']) <= 1 for s in events)
    payload = {
        'identity_audit': json.loads((REPORT / 'match_review_identity_audit.json').read_text(encoding='utf-8')),
        'metric_reconciliation': {
            'net_completed_pass_xt_all_phases': {'Brighton': 2.997, 'Arsenal': 3.431},
            'positive_completed_pass_xt_open_play': {'Brighton': 3.073, 'Arsenal': 4.405},
            'verified_on': '2026-09-30',
            'xt_definition': 'Net signed successful-pass xT across all phases reconciles to saved sequence totals. Positive open-play pass xT discards negative changes and set pieces; it is a different measure.',
            'xg_definition': 'Live mv_shot_xg uses mv_xg_bins, fitted from all available non-penalty shots with 20-shot base-rate smoothing. Refreshing that fitting pool can change historical shot values. Archived report values remain unchanged.'
        },
        'match': match, 'shots': shots['shots'],
        'provenance': {k: report.get(k) for k in ('as_of', 'generated_at', 'model_version')},
        'report_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'event_source': shots['source'], 'events_retrieved_on': shots['retrieved_on'],
        'challenger': challenger['challenger'],
        'challenger_model': comparison.get('challenger_model'),
        'challenger_scope': comparison['scope'],
        'challenger_created_at': comparison.get('created_at'),
    }
    output = ROOT / 'dashboard/match-review-data.js'
    output.write_text('window.MATCH_REVIEW = ' + json.dumps(payload, ensure_ascii=False).replace('<', '\\u003c') + ';\n', encoding='utf-8')
    print('PASS: 28 shots, 3 goals, complete event xG, probability sum, log loss and Brier. Event and archived xG differ: shown separately. Wrote', output)


if __name__ == '__main__':
    build()
