"""Executable editorial reference, NOT the Godot runtime integration.

Only the Python standard library is required. No player save files are read.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import random
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = json.loads((ROOT/'data/story_life_comic.json').read_text(encoding='utf-8'))
EVENTS = {event['id']:event for event in PACK['events']}

def tier(score):
    return min(3,max(0,int(score)//25))

def rng_for(seed, namespace):
    digest = hashlib.sha256(f'{seed}:{namespace}'.encode()).digest()
    return random.Random(int.from_bytes(digest,'big'))

def table_value(table, age):
    return next(value for lo,hi,value in table if lo<=age<=hi)

def hazard(age, physical, mental, illness=None):
    rules = PACK['rules']['mortality']
    body = 0.65+1.10*(100-max(0,min(100,physical)))/100
    mind = 0.92+0.16*(100-max(0,min(100,mental)))/100
    baseline = table_value(rules['annual_age_base'],age)*body*mind
    disease = rules['active_illness_extra_hazard'].get(illness,0)
    return baseline,disease,rules['sudden_fatal_accident_per_year']

def render_voice(event, outcome, narrative_tier):
    """Pure selection: changing the lens consumes no RNG and changes no facts."""
    return copy.deepcopy((outcome['voices'] if outcome else event['lenses'])[narrative_tier])

def tuples(value):
    return tuple(tuples(item) for item in value) if isinstance(value,list) else value

class Run:
    def __init__(self, seed, abstraction=None):
        self.seed = seed
        self.streams = {name:rng_for(seed,name) for name in PACK['rules']['persistence']['streams']}
        setup = self.streams['npc']
        self.scores = {'physical':setup.randint(45,85),'mental':setup.randint(45,85),
                       'abstract':setup.randint(0,55) if abstraction is None else abstraction,'money':0}
        self.age = 0
        self.flags = set()
        self.history = []
        self.rare_history = []
        self.seen = {}
        self.pending = None
        self.committed = None
        self.illness = None
        self.terminal = None
        self.ended = False
        self.budget = self.streams['layout'].randint(18,24)
        self.retire_age = setup.randint(55,74)
        self.partner_age = setup.choice([20,24,31,None])
        self.house_age = setup.randint(18,28)
        self.study_until = setup.choice([18,21,24])
        self.work_from = setup.randint(16,25)
        self.roles = {}
        for role,offset in [('parent',setup.randint(22,38)),('mate',setup.randint(22,40)),
                            ('friend',setup.randint(-2,2)),('teacher',25),('boss',15),
                            ('partner',setup.randint(-5,5)),('neighbor',setup.randint(-12,0))]:
            death_at = max(1,setup.randint(68,108)-offset)
            self.roles[role] = {'id':f'{seed}:{role}:1','alive':True,'death_at':death_at}
        # A clinician is a scene-local new adult, not the father sprite's identity.
        for role in ['clinician','hobby_admin','community_teacher']:
            self.roles[role] = {'id':f'{seed}:{role}:scene','alive':True,'death_at':999}

    def eligible(self, event):
        if self.ended: return False
        lo,hi = event['age_range']
        if not lo<=self.age<=hi: return False
        recurrence = event['recurrence']
        if event['id'] in self.seen:
            if recurrence['once'] or self.age-self.seen[event['id']]<recurrence['cooldown_years']: return False
        req = event['requirements']
        if req.get('education') and not 4<=self.age<=self.study_until: return False
        if req.get('education_or_hobby_group') and not (12<=self.age<=self.study_until or '_爱好_预约' in self.flags): return False
        if req.get('employed') and not self.work_from<=self.age<self.retire_age: return False
        if req.get('independent_housing') and self.age<self.house_age: return False
        if req.get('relationship_active') and (self.partner_age is None or self.age<self.partner_age): return False
        if req.get('memory_any') and not any(memory in self.flags for memory in req['memory_any']): return False
        if any(memory in self.flags for memory in req.get('memory_none',[])): return False
        required_roles = set(req.get('roles_available',[]))
        required_roles.update(role for role in event['cast_bindings'].values() if role!='lead')
        if any(not self.roles.get(role,{}).get('alive',False) for role in required_roles): return False
        # A partner must not appear before the relationship starts, even incidentally.
        if 'partner' in required_roles and (self.partner_age is None or self.age<self.partner_age): return False
        return True

    def begin(self, key):
        if self.pending is not None: return copy.deepcopy(self.pending)
        ev = EVENTS[key]
        if not self.eligible(ev): raise ValueError(f'ineligible event {key} at {self.age}')
        self.pending = {'event_id':key,'age':self.age,'opening_tier':tier(self.scores['abstract'])}
        return copy.deepcopy(self.pending)

    def choose(self, index):
        if self.ended: raise ValueError('life already ended')
        if self.pending is None: raise ValueError('no event to choose')
        if self.committed is not None:
            if self.committed['choice_index'] != index: raise ValueError('choice already committed')
            return copy.deepcopy(self.committed)
        ev = EVENTS[self.pending['event_id']]
        selected = ev['choices'][index]
        # The authored intent/cost applies regardless of what the world does next.
        for key,delta in selected['effects'].items():
            self.scores[key] = self.scores.get(key,0)+delta
            if key!='money': self.scores[key] = max(0,min(100,self.scores[key]))
        outcome = self.streams['outcome'].choices(selected['outcomes'],weights=[o['weight'] for o in selected['outcomes']],k=1)[0]
        for key,delta in outcome['effects'].items():
            self.scores[key] = self.scores.get(key,0)+delta
            if key!='money': self.scores[key] = max(0,min(100,self.scores[key]))
        self.flags.update([selected['memory'],outcome['memory']])
        self.seen[ev['id']] = self.age
        self.committed = {**self.pending,'choice_index':index,'intent':selected['intent'],
                          'outcome_id':outcome['id'],'facts':outcome['facts'],
                          'result_tier':tier(self.scores['abstract']),
                          'voice':render_voice(ev,outcome,tier(self.scores['abstract']))}
        self.history.append(copy.deepcopy(self.committed))
        return copy.deepcopy(self.committed)

    def finish(self):
        if self.committed is None: raise ValueError('cannot leave an unresolved choice')
        self.pending = self.committed = None

    def annual(self, forced_health=None):
        if self.ended: raise ValueError('cannot advance a completed life')
        if self.pending is not None: raise ValueError('finish current page first')
        for role,value in self.roles.items():
            if value['alive'] and self.age>=value['death_at']:
                value['alive'] = False
                self.rare_history.append({'id':'RX06','age':self.age,'role_id':value['id']})
        if forced_health is not None:
            self.scores['physical'],self.scores['mental'] = forced_health
        base,disease,accident = hazard(self.age,self.scores['physical'],self.scores['mental'],self.illness)
        roll = self.streams['mortality'].random()
        cause = None
        if roll<accident: cause = 'accident'
        elif roll<accident+disease: cause = 'illness'
        elif roll<accident+disease+base: cause = 'age_related' if self.age>=60 else 'other_illness'
        if cause:
            self.terminal = {'age':self.age,'cause':cause,'ending':{'accident':'END_ACCIDENT','illness':'END_ILLNESS','other_illness':'END_ILLNESS','age_related':'END_NATURAL'}[cause],
                             'overlays':(['END_EARLY'] if self.age<18 else [])}
            self.ended = True
            return
        illness_stream = self.streams['illness']
        onset_roll,progress_roll = illness_stream.random(),illness_stream.random()
        onset = table_value(PACK['rules']['mortality']['unexpected_cancer_onset'],self.age)
        if self.illness is None and onset_roll<onset:
            self.illness = 'stable'
            self.rare_history.extend({'id':key,'age':self.age,'state':'pending_editorial_scene'} for key in ['RX01','RX02','RX03'])
        elif self.illness is not None and self.age%2==0:
            self.illness = 'stable' if progress_roll<0.40 else ('remission' if progress_roll<0.75 else 'progression')
            self.rare_history.append({'id':'RX03','age':self.age,'state':self.illness})
        if forced_health is None:
            self.scores['physical'] = max(0,self.scores['physical']-(0.6 if self.age>=60 else (0.2 if self.age>=40 else 0)))

    def export(self):
        state = copy.deepcopy(self.__dict__)
        state['streams'] = {name:rng.getstate() for name,rng in self.streams.items()}
        state['flags'] = sorted(self.flags)
        return json.dumps(state,ensure_ascii=False)

    @classmethod
    def restore(cls, payload):
        data = json.loads(payload)
        obj = cls(data['seed'])
        stream_states = data.pop('streams')
        obj.__dict__.update(data)
        obj.flags = set(obj.flags)
        for name,state in stream_states.items(): obj.streams[name].setstate(tuples(state))
        return obj

def sample_life(seed, abstraction=None, forced_health=None, choice_policy=None):
    run = Run(seed,abstraction)
    # A birth panel is allowed before the first annual hazard; no adult speech is audible.
    run.begin('LC01');run.choose(0 if choice_policy is None else choice_policy(0));run.finish()
    for age in range(141):
        run.age = age
        run.annual(forced_health)
        if run.ended: break
        pool = [ev for ev in PACK['events'] if run.eligible(ev)]
        if pool and len(run.history)<run.budget:
            rng = run.streams['event']
            if age in [1,4,7,13,18,30,45,65] or rng.random()<0.35:
                ev = rng.choice(pool)
                run.begin(ev['id'])
                run.choose(rng.randrange(3) if choice_policy is None else choice_policy(len(run.history)))
                run.finish()
    if not run.ended:
        run.terminal = {'age':140,'cause':'unfinished','ending':'END_OPEN','overlays':[]}
    return run

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seed',type=int,default=42)
    parser.add_argument('--survey',type=int)
    parser.add_argument('--export',type=Path)
    args = parser.parse_args()
    if args.survey:
        runs = [sample_life(seed) for seed in range(args.survey)]
        print(json.dumps({'runs':len(runs),'mean_age':round(statistics.mean(run.terminal['age'] for run in runs),2),
          'min_age':min(run.terminal['age'] for run in runs),'max_age':max(run.terminal['age'] for run in runs),
          'mean_choices':round(statistics.mean(len(run.history) for run in runs),2)},ensure_ascii=False))
    else:
        run = sample_life(args.seed)
        result = {'seed':run.seed,'terminal':run.terminal,'pages':run.history,'rare_arcs':run.rare_history}
        if args.export: args.export.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        else: print(json.dumps(result,ensure_ascii=False,indent=2))
