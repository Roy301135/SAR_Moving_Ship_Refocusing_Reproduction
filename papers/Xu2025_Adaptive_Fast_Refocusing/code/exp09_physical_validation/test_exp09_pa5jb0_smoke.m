function report = test_exp09_pa5jb0_smoke()
%TEST_EXP09_PA5JB0_SMOKE Deterministic engineering checks; no formal data.
cfg=config_exp09_pa5jb0_complementarity();
checks=string.empty(0,1); passed=false(0,1); details=string.empty(0,1);
add('frozen_indicator_order',isequal(cfg.indicators,["refined_lr_asymmetry","fivebin_peak_fraction","local_entropy5"]),'three frozen indicators');
add('frozen_risk_directions',isequal(cfg.risk_directions,["high","low","high"]),'high / low / high');
add('frozen_budgets',isequal(cfg.budgets,[0,0.005,0.01,0.02,0.05,0.10,0.20,0.30,0.50,0.75,1]),'all 11 budgets');
q=pa5jb0_select_tie_inclusive([9;8;8;1],0.5);
add('tie_inclusive_selection',isequal(q.trigger,[true;true;true;false]) && q.actual_n==3 && q.cutoff_tie_count==2,'tie class expands nominal top-2 to 3');
q0=pa5jb0_select_tie_inclusive([9;8;8;1],0);
add('zero_budget',~any(q0.trigger) && isnan(q0.cutoff_score),'empty trigger set and NA cutoff');
q1=pa5jb0_select_tie_inclusive([9;8;8;1],1);
add('full_budget',all(q1.trigger) && q1.actual_fraction==1,'all trials trigger');
[p,lo,hi]=pa5jb0_wilson_ci(0,0,cfg.wilson_z);
add('wilson_zero_denominator',isnan(p) && isnan(lo) && isnan(hi),'undefined rate is NA');
[p,lo,hi]=pa5jb0_wilson_ci(1,2,cfg.wilson_z);
add('wilson_finite_interval',p==0.5 && lo>=0 && hi<=1 && lo<p && hi>p,'finite Wilson interval');
if ~all(passed), error('PA5JB0:SmokeFailure','One or more PA5J-B0 smoke checks failed.'); end
report=table(checks,passed,details);
disp(report);
    function add(name,ok,detail)
        checks(end+1,1)=name; passed(end+1,1)=ok; details(end+1,1)=detail;
    end
end
