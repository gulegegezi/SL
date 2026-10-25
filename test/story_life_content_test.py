"""Story data invariants and deterministic editorial simulation checks."""
import importlib.util
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from story_life_reference import EVENTS, PACK, Run, hazard, render_voice, sample_life, tier

def check():
    seen = set()
    assert len(PACK['events']) == 34
    assert len(PACK['rare_arcs']) == 6 and len(PACK['endings']) == 6
    counts = [0,0]
    for ev in PACK['events']:
        assert ev['id'] not in seen;seen.add(ev['id'])
        assert 0<=ev['age_range'][0]<=ev['age_range'][1]<=125
        assert len(ev['lenses'])==4 and len(ev['choices'])==3
        assert len(ev['panels'])==4 and ev['facts'] and ev['npc_dialogue']
        assert ev['cast_bindings'].keys()==set(ev['actors'])
        for i,lens in enumerate(ev['lenses']):
            assert lens['tier']==i and all(lens.get(key) for key in ['narrator','inner','dialogue','result_tail'])
        for choice in ev['choices']:
            counts[0]+=1
            assert choice['id'] not in seen;seen.add(choice['id'])
            assert choice['memory'] and len(choice['outcomes'])==2 and len(choice['lines'])==4
            assert sum(out['weight']>0 for out in choice['outcomes'])==2
            assert len({out['facts'] for out in choice['outcomes']})==2
            for out in choice['outcomes']:
                counts[1]+=1
                assert out['id'] not in seen;seen.add(out['id'])
                assert len(out['panels'])==3 and len(out['voices'])==4
                for i,voice in enumerate(out['voices']):
                    assert voice['tier']==i and voice['narrator'].startswith(out['facts'])
                    assert voice['dialogue']==choice['lines'][i]
    assert counts==[len(PACK['events'])*3,len(PACK['events'])*6]
    for age in [0,1,4,8,15,22,35,50,70,90]:
        run=Run(42);run.age=age;run.study_until=24;run.work_from=16;run.retire_age=75
        run.partner_age=20;run.house_age=18
        for role in run.roles.values():role['alive']=True
        assert len([ev for ev in PACK['events'] if run.eligible(ev)])>=(1 if age==0 else 2),(age,'sparse age pool')
    run=Run(13);run.age=12
    assert not run.eligible(EVENTS['LC12']) and not run.eligible(EVENTS['LC16'])
    run.age=35;run.roles['parent']['alive']=False
    assert not run.eligible(EVENTS['LC19'])
    run.roles['mate']['alive']=False
    assert run.eligible(EVENTS['LC18']),'doctor art slot must not resurrect father'
    run.age=70;run.roles['teacher']['alive']=False
    assert run.eligible(EVENTS['LC22']),'community instructor must not resurrect childhood teacher'
    run.age=10;run.flags.add('legacy:V01')
    assert not run.eligible(EVENTS['LC06']),'do not introduce the same schoolmate twice after importing a save'
    run=Run(18);run.age=10;run.begin('LC06')
    before=run.export()
    result=run.choose(0)
    assert Run.restore(before).choose(0)==result,'reload must preserve outcome RNG'
    after=run.export()
    assert run.choose(0)==result and run.export()==after,'same click must commit exactly once'
    restored=Run.restore(after)
    assert restored.choose(0)==result and restored.export()==after
    try:run.choose(1);raise AssertionError('must not change a committed choice')
    except ValueError:pass
    run.finish();restored.finish()
    assert run.streams['outcome'].random()==restored.streams['outcome'].random()
    for initial in [24,49,74]:
        run=Run(4,initial);run.age=10;run.begin('LC06');result=run.choose(0)
        assert result['opening_tier']==tier(initial) and result['result_tier']==tier(initial+1)
        assert Run.restore(run.export()).history[-1]['result_tier']==tier(initial+1)
    for seed in range(80):
        plain,absurd=sample_life(seed,0),sample_life(seed,100)
        key=lambda run:([(p['event_id'],p['age'],p['choice_index'],p['outcome_id']) for p in run.history],run.terminal,run.rare_history)
        assert key(plain)==key(absurd),'style must never change reality or mortality RNG'
    # All six outcomes of every event must be reachable, regardless of style.
    reached=set()
    for ev in PACK['events']:
        for ci in range(3):
            outcomes=set()
            for seed in range(60):
                run=Run(seed);run.age=max(ev['age_range'][0],18 if ev['requirements'].get('independent_housing') else 0)
                run.study_until=125;run.work_from=16;run.retire_age=126;run.partner_age=0;run.house_age=0
                for role in run.roles.values():role['alive']=True
                run.flags.update(ev['requirements'].get('memory_any',[]))
                run.begin(ev['id']);outcomes.add(run.choose(ci)['outcome_id'])
            assert len(outcomes)==2,(ev['id'],ci)
            reached.update(outcomes)
    assert len(reached)==len(PACK['events'])*6
    low=[];high=[];causes=set();diseased_at_high_health=0
    for seed in range(400):
        weak=sample_life(seed,forced_health=(20,20))
        healthy=sample_life(seed,forced_health=(95,95))
        low.append(weak.terminal['age']);high.append(healthy.terminal['age'])
        assert high[-1]>=low[-1],'paired health streams must give the healthier body no larger background hazard'
        causes.add(healthy.terminal['cause'])
        diseased_at_high_health+=any(page['id']=='RX02' for page in healthy.rare_history)
        for current in [weak,healthy]:
            for page in current.history:
                lo,hi=EVENTS[page['event_id']]['age_range'];assert lo<=page['age']<=hi
                assert page['age']<=current.terminal['age']
    assert statistics.mean(high)>statistics.mean(low)+5
    assert 'accident' in causes and diseased_at_high_health>0,'high health must not remove surprises'
    assert hazard(30,100,0)[0]>0 and hazard(30,100,0)[0]<0.01,'mental zero is not an instant death condition'
    spec=importlib.util.spec_from_file_location('builder',ROOT/'tools/build_story_life_comic.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    assert {e['id'] for e in module.build()['events']} <= {e['id'] for e in PACK['events']}, 'original scaffold events remain in the edited content pack'
    print(json.dumps({'status':'PASS','events':len(PACK['events']),'choices':counts[0],'random_results':counts[1],'tiers':4,
      'reachable_results':len(reached),'style_paired_lives':80,'health_paired_lives':400,
      'low_health_mean_age':round(statistics.mean(low),2),'high_health_mean_age':round(statistics.mean(high),2),
      'high_health_cancer_arcs':diseased_at_high_health,'high_health_causes':sorted(causes)},ensure_ascii=False))

if __name__=='__main__':check()
