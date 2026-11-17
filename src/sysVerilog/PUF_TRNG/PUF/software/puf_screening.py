"""Training-only 320-to-256 selection, using exact rational gap ranking."""
from fractions import Fraction


class Stats:
    def __init__(self, reference=None):
        self.reference=reference
        self.n=self.faults=self.ties=self.flips=self.weak=self.ones=self.zeros=0
        self.min_abs=None
        self.min_gap=None

    def add(self,row):
        self.n+=1
        if row['status']:
            self.faults+=1
            return
        delta=row['count_a']-row['count_b']
        bit=int(delta>0) if delta else None
        self.min_abs=abs(delta) if self.min_abs is None else min(self.min_abs,abs(delta))
        gap=Fraction(abs(delta),row['count_a']+row['count_b']) if row['count_a']+row['count_b'] else Fraction(0)
        self.min_gap=gap if self.min_gap is None else min(self.min_gap,gap)
        self.weak+=abs(delta)<8
        self.ties+=bit is None
        self.ones+=bit==1
        self.zeros+=bit==0
        if self.reference is not None:self.flips+=bit is not None and bit!=self.reference

    def record(self,pair):
        return dict(pair=pair,samples=self.n,faults=self.faults,ties=self.ties,
                    flips=self.flips,weak=self.weak,ones=self.ones,zeros=self.zeros,
                    reference=self.reference,min_abs=self.min_abs,
                    min_gap_ratio=str(self.min_gap) if self.min_gap is not None else None)


def references(stats,reads):
    return [int(s.ones>s.zeros) if s.n==reads and max(s.ones,s.zeros)==reads and not s.faults and not s.weak
            else None for s in stats]


def freeze(reference,training,reads):
    if len(reference)!=320 or len(training)!=320:raise ValueError('Expected 320 pairs')
    eligible=[p for p,s in enumerate(training) if reference[p] is not None and s.n==reads
              and not (s.faults or s.ties or s.flips or s.weak) and s.min_gap is not None]
    ranking=sorted(eligible,key=lambda p:(-training[p].min_gap,-training[p].min_abs,p))
    selected=sorted(ranking[:256])
    complete=len(selected)==256
    candidate=sum(reference[p]<<j for j,p in enumerate(selected)) if complete else None
    return dict(complete=complete,eligible_count=len(eligible),ranked_eligible=ranking,
                selected_pairs=selected,bitmap_hex=format(sum(1<<p for p in selected),'080x'),
                reference_candidate_hex=format(candidate,'064x') if complete else None,
                ranking_rule='Stable initial references; training has zero faults/ties/flips or abs(A-B)<8. '
                             'Descending exact minimum abs(A-B)/(A+B), then minimum abs(A-B), then ascending pair ID. '
                             'Freeze before holdout; never replace failed holdout pairs.',
                bit_order='bitmap bit p selects pair p; candidate bit j is selected_pairs[j] in ascending order')


def validate(selection,holdout,reads):
    failed=[p for p in selection['selected_pairs'] if holdout[p].n!=reads or holdout[p].reference is None
            or holdout[p].faults or holdout[p].ties or holdout[p].flips or holdout[p].weak]
    return dict(passed=selection['complete'] and not failed,failed_pairs=failed,
                selected_count=len(selection['selected_pairs']),reads_per_pair=reads)
