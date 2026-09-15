function S = pa5jb0_select_tie_inclusive(score,budget)
%PA5JB0_SELECT_TIE_INCLUSIVE Frozen cutoff-tie protocol; never uses row order.
score = score(:);
if any(~isfinite(score)), error('PA5JB0:NonfiniteScore','Risk score must be finite.'); end
n = numel(score);
if n==0, error('PA5JB0:EmptyGroup','Cannot rank an empty analysis group.'); end
if budget<0 || budget>1, error('PA5JB0:InvalidBudget','Budget must be in [0,1].'); end
if budget==0
    trigger=false(n,1); cutoff=NaN; ties=0; nominal_n=0;
else
    nominal_n=ceil(budget*n); ordered=sort(score,'descend'); cutoff=ordered(nominal_n);
    trigger=score>=cutoff; ties=sum(score==cutoff);
end
actual_n=sum(trigger);
S=struct('trigger',trigger,'nominal_budget',budget,'nominal_n',nominal_n, ...
    'actual_n',actual_n,'actual_fraction',actual_n/n,'cutoff_score',cutoff, ...
    'cutoff_tie_count',ties,'budget_inflation',actual_n/n-budget);
end
